extends Node3D
# class_name SandboxWorld  # Removed to avoid conflicts during refactoring

## Main sandbox world controller
## Coordinates world generation, camera setup, and debug UI

## Node references
@onready var world_generator = $WorldGenerator
@onready var camera = $FreeCamera
@onready var debug_ui = $DebugUI if has_node("DebugUI") else null

## World generation settings
@export var auto_generate: bool = true
@export var generation_delay: float = 0.5

## World generation parameters
@export_group("Generation Parameters")
@export_range(1, 3) var n_factions: int = 3 ## Number of factions (1 for testing, 3 for full game)
@export var n_motherships_per_faction: int = 3 ## Motherships per faction
@export var n_squads_per_mothership: int = 3 ## Squads per mothership
@export var world_size_override: float = 0.0 ## World size (0 = use WorldGenerator default)
@export var n_resources: int = 0 ## Number of resources (0 = use WorldGenerator default)
@export var generation_seed: int = 0 ## World generation seed (0 = random)

## Debug UI visibility
var debug_ui_visible: bool = true


func _ready() -> void:
	print("[SandboxWorld] Initializing sandbox environment...")

	# Start loading screen
	LoadingManager.start_loading()

	# Connect world generator signals
	if world_generator:
		world_generator.generation_started.connect(_on_generation_started)
		world_generator.generation_completed.connect(_on_generation_completed)
		world_generator.motherships_placed.connect(_on_motherships_placed)
		world_generator.pois_placed.connect(_on_pois_placed)

	# Generate world after short delay (allows scene to fully load)
	if auto_generate:
		LoadingManager.update_progress("resources", 0.5, "Loading resources...")
		await get_tree().create_timer(generation_delay).timeout
		LoadingManager.update_progress("resources", 1.0, "Resources loaded")

		LoadingManager.update_progress("world", 0.0, "Generating world...")
		generate_world()

		# Position camera and player after terrain is generated
		await get_tree().create_timer(0.5).timeout

		LoadingManager.update_progress("player", 0.5, "Spawning player...")
		_position_player_on_terrain()
		LoadingManager.update_progress("player", 1.0, "Player spawned")

		LoadingManager.update_progress("camera", 0.5, "Setting up camera...")
		_setup_camera()
		LoadingManager.update_progress("camera", 1.0, "Camera ready")

		# Finish loading
		LoadingManager.finish_loading()


func _input(event: InputEvent) -> void:
	# Toggle debug UI with F1
	if event.is_action_pressed("ui_home") or (event is InputEventKey and event.keycode == KEY_F1 and event.pressed):
		toggle_debug_ui()
		get_viewport().set_input_as_handled()

	# Regenerate world with R key
	if event is InputEventKey and event.keycode == KEY_R and event.pressed:
		print("[SandboxWorld] Regenerating world...")
		generate_world()
		get_viewport().set_input_as_handled()


## Generate the world
func generate_world() -> void:
	if not world_generator:
		push_error("[SandboxWorld] WorldGenerator not found!")
		return

	print("[SandboxWorld] Triggering world generation...")

	# Build parameters, using configured values or WorldGenerator defaults
	var factions: int = n_factions
	var motherships_per_faction: int = n_motherships_per_faction
	var squads_per_mothership: int = n_squads_per_mothership
	var size: float = world_size_override if world_size_override > 0.0 else world_generator.world_size
	var resources: int = n_resources if n_resources > 0 else world_generator.poi_count

	print("[SandboxWorld] Generation config: %d factions, %d motherships/faction, %d squads/mothership" % [
		factions, motherships_per_faction, squads_per_mothership
	])

	world_generator.generate_world(factions, motherships_per_faction, squads_per_mothership, size, resources, generation_seed)


## Setup camera for good initial view (call AFTER terrain generation)
func _setup_camera() -> void:
	if not camera or not world_generator:
		return

	# Calculate terrain height at camera spawn position (0, ?, 300)
	var camera_x := 0.0
	var camera_z := 300.0
	var terrain_height_at_camera: float = world_generator.get_terrain_height_at(camera_x, camera_z)
	var terrain_height_at_origin: float = world_generator.get_terrain_height_at(0.0, 0.0)

	# Position camera 200m above terrain at its spawn location
	var start_pos := Vector3(camera_x, terrain_height_at_camera + 200.0, camera_z)
	# Look at origin point at terrain level
	var look_target := Vector3(0, terrain_height_at_origin, 0)

	camera.set_position_and_target(start_pos, look_target)
	print("[SandboxWorld] Camera positioned at %v (terrain: %.1f), looking at %v (terrain: %.1f)" % [
		start_pos, terrain_height_at_camera, look_target, terrain_height_at_origin
	])


## Toggle debug UI visibility
func toggle_debug_ui() -> void:
	if not debug_ui:
		return

	debug_ui_visible = !debug_ui_visible
	debug_ui.visible = debug_ui_visible

	if debug_ui_visible:
		print("[SandboxWorld] Debug UI: ON")
	else:
		print("[SandboxWorld] Debug UI: OFF")


## Position player drone on terrain at proper height
func _position_player_on_terrain() -> void:
	var player := get_node_or_null("Player")
	if not player or not world_generator:
		return

	# Get player's current X,Z position (or use 0,0)
	var player_x: float = player.global_position.x
	var player_z: float = player.global_position.z

	# Get terrain height at that position
	var terrain_height: float = world_generator.get_terrain_height_at(player_x, player_z)

	# Spawn player 25m above terrain (hover altitude)
	var spawn_height := terrain_height + 25.0
	player.global_position = Vector3(player_x, spawn_height, player_z)

	print("[SandboxWorld] Positioned player at (%f, %f, %f) - terrain: %f" % [
		player_x, spawn_height, player_z, terrain_height
	])

	# Also update player camera position
	var player_camera := get_node_or_null("PlayerCamera")
	if player_camera:
		player_camera.global_position = Vector3(player_x, spawn_height + 3.5, player_z - 7)


## Update debug UI with latest stats
func _update_debug_ui() -> void:
	if not debug_ui or not debug_ui_visible:
		return

	# Update FPS
	var fps_label := debug_ui.get_node_or_null("Panel/VBoxContainer/FPS") as Label
	if fps_label:
		fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

	# Update entity counts
	var entities_label := debug_ui.get_node_or_null("Panel/VBoxContainer/Entities") as Label
	if entities_label and world_generator:
		var mothership_count: int = world_generator.get_motherships().size()
		var poi_count: int = world_generator.get_pois().size()
		entities_label.text = "Motherships: %d | POIs: %d" % [mothership_count, poi_count]

	# Update faction stats if FactionManager exists
	var faction_stats_label := debug_ui.get_node_or_null("Panel/VBoxContainer/FactionStats") as Label
	if faction_stats_label:
		faction_stats_label.text = _get_faction_stats()


## Get faction statistics string
func _get_faction_stats() -> String:
	# Try to access FactionManager
	var faction_manager: Node = null
	if has_node("/root/FactionManager"):
		faction_manager = get_node("/root/FactionManager")

	if not faction_manager:
		return "Faction Manager: Not Found"

	# Get faction data
	var stats_lines: Array[String] = ["Faction Stats:"]

	for i in range(3):
		var faction_name := "Faction %d" % i
		var squad_count := 0
		var total_resources := 0

		# Try to get faction data
		if faction_manager.has_method("get_faction_squads"):
			var squads = faction_manager.get_faction_squads(i)
			if squads:
				squad_count = squads.size()

		if faction_manager.has_method("get_faction_resources"):
			total_resources = faction_manager.get_faction_resources(i)

		stats_lines.append("  %s: %d squads, %d resources" % [faction_name, squad_count, total_resources])

	return "\n".join(stats_lines)


## Called every frame for debug UI updates
func _process(_delta: float) -> void:
	if debug_ui and debug_ui_visible:
		_update_debug_ui()


# Signal handlers
func _on_generation_started() -> void:
	print("[SandboxWorld] >>> World generation started")
	LoadingManager.update_progress("world", 0.1, "Generating terrain...")


func _on_generation_completed() -> void:
	print("[SandboxWorld] >>> World generation completed!")
	_log_world_summary()
	LoadingManager.update_progress("world", 0.9, "World generated")

	# Spawn initial squads from each mothership
	LoadingManager.update_progress("factions", 0.0, "Initializing factions...")
	await get_tree().create_timer(1.0).timeout # Wait a second for everything to settle
	_spawn_initial_squads()
	LoadingManager.update_progress("factions", 1.0, "Factions ready")


func _on_motherships_placed(count: int) -> void:
	print("[SandboxWorld] >>> Motherships placed: %d" % count)
	LoadingManager.update_progress("world", 0.5, "Placing motherships...")


func _on_pois_placed(count: int) -> void:
	print("[SandboxWorld] >>> POIs placed: %d" % count)
	LoadingManager.update_progress("world", 0.7, "Placing resources...")


## Log comprehensive world summary
func _log_world_summary() -> void:
	if not world_generator:
		return

	print("\n========== SANDBOX WORLD SUMMARY ==========")
	print("World Size: %.0fm x %.0fm" % [world_generator.world_size, world_generator.world_size])
	print("Motherships: %d" % world_generator.get_motherships().size())
	print("POIs: %d" % world_generator.get_pois().size())
	print("")

	# List motherships by faction
	var motherships: Array = world_generator.get_motherships()
	var faction_counts: Array = [0, 0, 0]

	for mothership in motherships:
		var faction_id := -1
		if "owning_faction" in mothership:
			faction_id = mothership.owning_faction
		elif mothership.has_method("get_faction"):
			faction_id = mothership.get_faction()

		if faction_id >= 0 and faction_id < 3:
			faction_counts[faction_id] += 1

	print("Faction Distribution:")
	for i in range(3):
		print("  Faction %d: %d motherships" % [i, faction_counts[i]])

	print("===========================================\n")


## Spawn initial drone squads from all motherships
func _spawn_initial_squads() -> void:
	if not world_generator:
		return

	print("[SandboxWorld] Spawning initial drone squads...")

	var motherships: Array = world_generator.get_motherships()
	var total_squads_spawned := 0

	for mothership in motherships:
		if mothership and mothership.has_method("spawn_squad"):
			# Try to spawn a squad from this mothership
			mothership.spawn_squad()
			total_squads_spawned += 1

	print("[SandboxWorld] Spawned %d initial squads from %d motherships" % [total_squads_spawned, motherships.size()])
