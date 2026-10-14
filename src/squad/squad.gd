extends Node3D
class_name Squad

## Squad - Base Entity Class
##
## Represents a squad as a game entity with:
## - Identity (squad_id, faction_id, faction_color)
## - Membership management (drones array, add/remove)
## - Lifecycle events (initialization, destruction, drone deaths)
## - Visual representation (label, formation tracking)
##
## AI behavior is handled by SquadOrchestratorAI component (added as child)

# ============================================================================
# IDENTITY & CONFIGURATION
# ============================================================================

var squad_id: int = -1
var faction_id: int = -1
var faction_color: Color = Color.WHITE
var starting_squad_size: int = 0

@export var detection_radius: float = 200.0
@export var combat_range: float = 100.0
@export var formation_spacing: float = 5.0
@export var max_resources: int = 100

# ============================================================================
# MEMBERSHIP
# ============================================================================

var drones: Array[Node3D] = []

# ============================================================================
# VISUAL
# ============================================================================

var _label: Label3D = null

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	starting_squad_size = drones.size()
	_create_squad_label()
	set_physics_process(true)

	print("[Squad %d] INITIALIZED | Faction: %d | Drones: %d" % [
		squad_id, faction_id, drones.size()
	])


func _physics_process(_delta: float) -> void:
	_cleanup_invalid_drones()

	if drones.is_empty():
		_squad_destroyed()
		return

	# Update squad position to be centered on drones
	_update_drone_formation()


func initialize(p_squad_id: int, p_faction_id: int, p_faction_color: Color) -> void:
	squad_id = p_squad_id
	faction_id = p_faction_id
	faction_color = p_faction_color

# ============================================================================
# MEMBER MANAGEMENT
# ============================================================================

func add_drone(drone: Node3D) -> void:
	if not drone or not is_instance_valid(drone):
		push_error("[Squad %d] Cannot add invalid drone" % squad_id)
		return

	drones.append(drone)

	var orchestrator = drone.get_node_or_null("OrchestratorAI")
	if orchestrator:
		orchestrator.parent_squad = self
		orchestrator.is_squad_member = true

		if orchestrator.current_state != OrchestratorAI.AIState.PART_OF_SQUAD:
			orchestrator.transition_to_state(OrchestratorAI.AIState.PART_OF_SQUAD)

		var pathfinding_ai = orchestrator.pathfinding_ai
		if pathfinding_ai:
			pathfinding_ai.patrol_mode = false

	var health_sys := drone.get_node_or_null("HealthSystem")
	if health_sys and health_sys.has_signal("died"):
		if not health_sys.died.is_connected(_on_drone_died):
			health_sys.died.connect(_on_drone_died.bind(drone))


func remove_drone(drone: Node3D) -> void:
	drones.erase(drone)

	if drones.is_empty():
		_squad_destroyed()


func _cleanup_invalid_drones() -> void:
	var to_remove: Array[Node3D] = []
	for drone in drones:
		if not is_instance_valid(drone):
			to_remove.append(drone)
	for drone in to_remove:
		drones.erase(drone)


func _on_drone_died(drone: Node3D) -> void:
	if not is_instance_valid(drone):
		return

	remove_drone(drone)

	if FactionManager and FactionManager.has_method("get_faction"):
		var faction = FactionManager.get_faction(faction_id)
		if faction:
			faction.total_losses += 1


func _squad_destroyed() -> void:
	print("[Squad %d] SQUAD DESTROYED" % squad_id)

	# Notify AI component to cleanup
	var squad_ai = get_node_or_null("SquadOrchestratorAI")
	if squad_ai and squad_ai.has_method("on_squad_destroyed"):
		squad_ai.on_squad_destroyed()

	if FactionManager and FactionManager.has_method("unregister_squad"):
		FactionManager.unregister_squad(self)

	queue_free()

# ============================================================================
# FORMATION & POSITIONING
# ============================================================================

func _update_drone_formation() -> void:
	if drones.is_empty():
		return

	var center: Vector3 = Vector3.ZERO
	var valid_count: int = 0

	for drone in drones:
		if is_instance_valid(drone):
			center += drone.global_position
			valid_count += 1

	if valid_count > 0:
		center /= float(valid_count)
		global_position = center

# ============================================================================
# LABEL MANAGEMENT
# ============================================================================

func _create_squad_label() -> void:
	_label = Label3D.new()
	_label.name = "SquadLabel"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0, 15, 0)
	_label.pixel_size = 0.05
	_label.font_size = 64
	_label.outline_size = 16
	_label.outline_modulate = Color.BLACK
	_label.text = "Squad %d" % squad_id
	_label.modulate = faction_color
	_label.render_priority = 10
	add_child(_label)


## Update the squad's status label. Called by AI component.
func update_squad_label(status: String) -> void:
	if not _label or not is_instance_valid(_label):
		return

	_label.text = "Squad %d - %s" % [squad_id, status]
	_label.modulate = faction_color
