extends Node

## FactionManager - Singleton for managing all factions in the game
## Handles faction initialization, relations, and global tracking of squads/motherships/POIs

# Preload Faction class
const Faction = preload("res://src/faction/faction.gd")

## Singleton instance reference
static var instance: FactionManager

## All factions in the simulation (3 factions)
var factions: Array = []

## Global tracking arrays for quick lookups
var all_squads: Array = []
var all_motherships: Array = []
var all_pois: Array = []

## Globally unique squad id counter (per-faction indices collide in logs)
var _next_squad_uid: int = 0

# Configuration parameters
@export var max_squads_per_faction: int = 10
@export var squad_spawn_interval: float = 30.0
@export var ai_update_interval: float = 0.5


func _ready() -> void:
	instance = self
	_initialize_factions()
	print("[FactionManager] Initialized with %d factions" % factions.size())


## Initialize the 3 factions with preset names and colors
func _initialize_factions() -> void:
	var faction_configs: Array = [
		{"id": 0, "name": "Alpha Swarm", "color": Color.RED},
		{"id": 1, "name": "Beta Collective", "color": Color.BLUE},
		{"id": 2, "name": "Gamma Hive", "color": Color.GREEN}
	]

	for config in faction_configs:
		var faction: Faction = Faction.new(config.id, config.name, config.color)

		# Set hostile relations with all other factions
		for i in range(3):
			if i == config.id:
				faction.set_relation(i, 0.0) # Neutral with self
			else:
				faction.set_relation(i, -100.0) # Hostile with others

		factions.append(faction)
		print("[FactionManager] Created faction %d: %s (%s)" % [faction.faction_id, faction.faction_name, faction.faction_color])


## Get a faction by its ID
## Returns: Faction or null if not found
func get_faction(faction_id: int) -> Faction:
	if faction_id >= 0 and faction_id < factions.size():
		return factions[faction_id]
	push_error("[FactionManager] Invalid faction_id: %d" % faction_id)
	return null


## Check if two factions are hostile to each other
func is_hostile(faction_a_id: int, faction_b_id: int) -> bool:
	var faction_a: Faction = get_faction(faction_a_id)
	if faction_a == null:
		return false
	return faction_a.is_hostile_to(faction_b_id)


## Register a squad globally and with its faction
func register_squad(squad: Node) -> void:
	if not all_squads.has(squad):
		all_squads.append(squad)

		# Also register with the squad's faction
		if "faction_id" in squad:
			var faction: Faction = get_faction(squad.faction_id)
			if faction != null:
				faction.register_squad(squad)
				print("[FactionManager] Registered squad for faction %d" % squad.faction_id)


## Unregister a squad globally and from its faction
func unregister_squad(squad: Node) -> void:
	all_squads.erase(squad)

	# Also unregister from the squad's faction
	if "faction_id" in squad:
		var faction: Faction = get_faction(squad.faction_id)
		if faction != null:
			faction.unregister_squad(squad)
			print("[FactionManager] Unregistered squad from faction %d" % squad.faction_id)


## Register a mothership globally and with its faction
func register_mothership(mothership: Node) -> void:
	if not all_motherships.has(mothership):
		all_motherships.append(mothership)

		# Also register with the mothership's faction
		if "owning_faction" in mothership:
			var faction: Faction = get_faction(mothership.owning_faction)
			if faction != null:
				faction.register_mothership(mothership)
				print("[FactionManager] Registered mothership for faction %d" % mothership.owning_faction)


## Unregister a mothership globally and from its faction
func unregister_mothership(mothership: Node) -> void:
	all_motherships.erase(mothership)

	# Also unregister from the mothership's faction
	if "owning_faction" in mothership:
		var faction: Faction = get_faction(mothership.owning_faction)
		if faction != null:
			faction.unregister_mothership(mothership)
			print("[FactionManager] Unregistered mothership from faction %d" % mothership.owning_faction)


## Register a POI (Point of Interest) globally
func register_poi(poi: Node) -> void:
	if poi not in all_pois:
		all_pois.append(poi)
		print("[FactionManager] Registered POI at %s" % str(poi.global_position if "global_position" in poi else "unknown"))


## Unregister a POI globally
func unregister_poi(poi: Node) -> void:
	all_pois.erase(poi)
	print("[FactionManager] Unregistered POI")


## Get all squads belonging to a specific faction
func get_faction_squads(faction_id: int) -> Array:
	var faction: Faction = get_faction(faction_id)
	if faction != null:
		return faction.squads
	return []


## Get all motherships belonging to a specific faction
func get_faction_motherships(faction_id: int) -> Array:
	var faction: Faction = get_faction(faction_id)
	if faction != null:
		return faction.motherships
	return []


## Get statistics for all factions
func get_all_stats() -> String:
	var stats: String = "=== FACTION STATISTICS ===\n\n"
	for faction in factions:
		stats += faction.get_stats_summary() + "\n\n"
	return stats


## Print current faction statistics to console
func print_stats() -> void:
	print("\n" + get_all_stats())


## Spawn a drone squad from a mothership
## This is called by mothership.gd when it wants to spawn a new squad
func spawn_squad_from_mothership(
	faction_id: int,
	spawn_position: Vector3,
	mothership: Node
) -> Node3D:
	# Get faction
	var faction: Faction = get_faction(faction_id)
	if not faction:
		push_error("[FactionManager] Cannot spawn squad - invalid faction_id: %d" % faction_id)
		return null

	# Check squad limit
	if faction.squads.size() >= max_squads_per_faction:
		push_warning("[FactionManager] Faction %d at max squad limit (%d)" % [faction_id, max_squads_per_faction])
		return null

	# Load drone scenes
	# Load all drone type scenes
	var explorer_scene := load("res://scenes/drones/explorer_drone.tscn")
	var cargo_scene := load("res://scenes/drones/cargo_drone.tscn")
	var fighter1_scene := load("res://scenes/drones/fighter_drone_type1.tscn")
	var fighter2_scene := load("res://scenes/drones/fighter_drone_type2.tscn")

	if not explorer_scene or not cargo_scene or not fighter1_scene or not fighter2_scene:
		push_error("[FactionManager] Failed to load one or more drone scenes!")
		return null

	# Create squad node and add to scene FIRST
	var squad := Node3D.new()

	# Add to scene BEFORE setting script (important for initialization order)
	if mothership and mothership.get_parent():
		mothership.get_parent().add_child(squad)
		squad.global_position = spawn_position
	else:
		push_error("[FactionManager] Cannot add squad to scene - mothership has no parent!")
		squad.queue_free()
		return null

	# Set the Squad entity script (handles membership, lifecycle, visual representation)
	squad.set_script(load("res://src/squad/squad.gd"))

	# Add AI orchestrator component (handles decision-making and execution)
	var squad_ai := Node.new()
	squad_ai.set_script(load("res://src/ai/squad/squad_orchestrator_ai.gd"))
	squad_ai.name = "SquadOrchestratorAI"
	squad.add_child(squad_ai)

	# Add modular AI components as child nodes
	var combat_ai := Node.new()
	combat_ai.set_script(load("res://src/ai/squad/squad_combat_ai.gd"))
	combat_ai.name = "SquadCombatAI"
	squad.add_child(combat_ai)

	var mining_ai := Node.new()
	mining_ai.set_script(load("res://src/ai/squad/squad_mining_ai.gd"))
	mining_ai.name = "SquadMiningAI"
	squad.add_child(mining_ai)

	var navigation_ai := Node.new()
	navigation_ai.set_script(load("res://src/ai/squad/squad_navigation_ai.gd"))
	navigation_ai.name = "SquadNavigationAI"
	squad.add_child(navigation_ai)

	var formation_ai := Node.new()
	formation_ai.set_script(load("res://src/ai/squad/squad_formation_ai.gd"))
	formation_ai.name = "SquadFormationAI"
	squad.add_child(formation_ai)

	# Configure squad properties (after script is set)
	# Globally unique id so logs can tell squads of different factions apart
	var next_squad_id := _next_squad_uid
	_next_squad_uid += 1
	squad.squad_id = next_squad_id
	squad.faction_id = faction_id
	squad.faction_color = faction.faction_color
	squad.name = "Squad%d_F%d" % [next_squad_id, faction_id]

	print("[FactionManager] Squad node created at global position: %v with modular AI components" % spawn_position)

	# Define squad composition: one of each drone type
	var drone_composition := [
		explorer_scene, # Explorer (fast scout)
		cargo_scene, # Cargo (resource hauler)
		fighter1_scene, # Fighter Type 1 (heavy combat)
		fighter2_scene # Fighter Type 2 (fast interceptor)
	]
	var drone_types := ["Explorer", "Cargo", "Fighter1", "Fighter2"]

	# Spawn individual drones AFTER squad is in scene tree
	print("[FactionManager] Spawning %d drones for squad (1 Explorer, 1 Cargo, 1 Fighter1, 1 Fighter2)..." % drone_composition.size())

	var drones_spawned: int = 0
	for i in range(drone_composition.size()):
		var drone_scene = drone_composition[i]
		var drone := drone_scene.instantiate() as Node3D
		if not drone:
			continue

		# Set faction_id on the drone (needed for player attack detection)
		# Using metadata to ensure it persists
		drone.set_meta("faction_id", faction_id)

		# Descriptive name so AI decision logs identify the drone
		# (Godot appends a numeric suffix if the name collides)
		drone.name = "%s_S%d_F%d" % [drone_types[i], next_squad_id, faction_id]

		# Set MotionController to AI mode (control_mode = 1)
		if drone.has_node("MotionController"):
			var input_controller = drone.get_node("MotionController")
			input_controller.control_mode = 1 # AI mode

		# Add OrchestratorAI for squad drones
		var drone_ai := Node.new()
		var ai_script = load("res://src/ai/drone/drone_orchestrator_ai.gd")
		drone_ai.set_script(ai_script)
		drone_ai.name = "OrchestratorAI"
		drone_ai.set("drone", drone) # Set drone reference for AI
		drone.add_child(drone_ai)

		# Add 3D health bar for AI drones
		var healthbar_3d := Node3D.new()
		var healthbar_script = load("res://src/ui/drone_health_bar_3d.gd")
		healthbar_3d.set_script(healthbar_script)
		healthbar_3d.name = "HealthBar3D"
		# healthbar_3d.rotation.y = deg_to_rad(90)  # Rotate 90° on XZ plane
		healthbar_3d.set("bar_offset_y", 2.0)
		healthbar_3d.set("always_visible", false) # Only show when player shoots
		drone.add_child(healthbar_3d)

		# Set faction color BEFORE adding to scene (set the export property directly)
		if drone.has_node("DroneColorizer"):
			var colorizer = drone.get_node("DroneColorizer")
			colorizer.tint_color = faction.faction_color

		# Calculate drone position with random offset from squad spawn position
		var offset := Vector3(
			randf_range(-10, 10),
			randf_range(5, 10), # Larger Y offset to ensure drones spawn well above any terrain variation
			randf_range(-10, 10)
		)

		# Spawn at spawn_position + offset. Spawn position is already above terrain (15.5m).
		# Adding 5-10m more ensures drones spawn at 20-25m above assembly zone terrain.
		# Drones will use their hover physics to settle at proper altitude (3m above actual ground)
		var drone_global_pos := spawn_position + offset

		# Add drone to WORLD (same parent as squad), NOT as child of squad
		if mothership and mothership.get_parent():
			mothership.get_parent().add_child(drone)
			# Set global position AFTER adding to scene
			drone.global_position = drone_global_pos
		else:
			push_error("[FactionManager] Cannot add drone to scene - mothership has no parent!")
			drone.queue_free()
			continue

		print("  → %s drone %d spawned | Squad global: %v | Drone global: %v" % [
			drone_types[i], i, spawn_position, drone.global_position
		])

		# Register drone with squad immediately (don't use local array to avoid duplicates)
		if squad.has_method("add_drone"):
			squad.add_drone(drone)
		drones_spawned += 1

	# Manually call _ready() because setting script after adding to scene doesn't auto-call it
	if squad.has_method("_ready"):
		squad._ready()

	# Register squad
	register_squad(squad)

	print("[FactionManager] Spawned squad %d for faction %d with %d drones at %v" % [
		next_squad_id, faction_id, drones_spawned, spawn_position
	])

	return squad


## Add resources to a faction's total
## Called by motherships when they receive resources from squads
func add_faction_resources(faction_id: int, amount: int) -> void:
	var faction: Faction = get_faction(faction_id)
	if faction:
		faction.total_resources_collected += amount
		print("[FactionManager] Faction %d collected %d resources (total: %d)" % [
			faction_id, amount, faction.total_resources_collected
		])
