extends RigidBody3D
class_name BaseDrone

## Base Drone Class
## All drone types extend this
## Child classes MUST override _ready() to set specific motion stats
## Uses composition pattern with MotionSystem, HealthSystem, EnergySystem, etc.

## Signals (forwarded from systems)
signal health_changed(new_health: float, max_health: float)
signal shields_changed(new_shields: float, max_shields: float)
signal energy_changed(new_energy: float, max_energy: float)
signal boost_changed(boost_amount: float)
signal collision_occurred(impact_speed: float, damage: float)
signal drone_destroyed()

## System Components
var motion_system: MotionSystem = null
var health_system: HealthSystem = null
var energy_system: EnergySystem = null
var cargo_system = null
var input_controller = null
var aim_system = null
var weapon_controller = null


func _ready() -> void:
	# Find components
	_find_components()

	# Connect systems
	_connect_systems()

	# Child classes must call initialize_systems() after setting up their configs


func _find_components() -> void:
	## Find component nodes
	motion_system = get_node_or_null("MotionSystem")
	input_controller = get_node_or_null("MotionController")
	aim_system = get_node_or_null("AimSystem")
	weapon_controller = get_node_or_null("WeaponController")
	cargo_system = get_node_or_null("CargoSystem")
	health_system = get_node_or_null("HealthSystem")
	energy_system = get_node_or_null("EnergySystem")


func _connect_systems() -> void:
	## Connect to system signals
	if health_system:
		health_system.health_changed.connect(_on_health_changed)
		health_system.shields_changed.connect(_on_shields_changed)
		health_system.died.connect(_on_died)

	if energy_system:
		energy_system.energy_changed.connect(_on_energy_changed)

	if motion_system:
		motion_system.boost_changed.connect(_on_boost_changed)


## Signal Forwarding
func _on_health_changed(current: float, maximum: float) -> void:
	emit_signal("health_changed", current, maximum)


func _on_shields_changed(current: float, maximum: float) -> void:
	emit_signal("shields_changed", current, maximum)


func _on_energy_changed(current: float, maximum: float) -> void:
	emit_signal("energy_changed", current, maximum)


func _on_boost_changed(boost_amount: float) -> void:
	emit_signal("boost_changed", boost_amount)


func _on_died() -> void:
	## Called when drone health reaches zero
	emit_signal("drone_destroyed")

	# Disable physics
	set_physics_process(false)
	set_process(false)

	# Destroy the drone after a short delay
	await get_tree().create_timer(0.5).timeout
	queue_free()


## Energy Management (compatibility interface)
func has_energy(amount: float) -> bool:
	if energy_system:
		return energy_system.has_energy(amount)
	return false


func consume_energy(amount: float) -> void:
	if energy_system:
		energy_system.consume_energy(amount)


func get_energy_percent() -> float:
	if energy_system:
		return energy_system.get_energy_percentage()
	return 0.0


## Motion Interface (forward to MotionSystem)
func get_altitude() -> float:
	if motion_system:
		return motion_system.get_altitude()
	return 0.0


func set_ai_movement(move: Vector2, climb: float = 0.0) -> void:
	if motion_system:
		motion_system.set_ai_movement(move, climb)


func set_ai_fire(primary: bool, secondary: bool = false) -> void:
	if motion_system:
		motion_system.set_ai_fire(primary, secondary)


func set_ai_boost(enabled: bool) -> void:
	if motion_system:
		motion_system.set_ai_boost(enabled)


func set_ai_weapon_target(target_pos: Vector3) -> void:
	if motion_system:
		motion_system.set_ai_weapon_target(target_pos)


## AI Setup (called by child classes if needed)
func setup_ai(orchestrator_config: Dictionary, combat_config: Dictionary) -> void:
	## Setup AI system if this drone is not player-controlled
	## orchestrator_config: field_of_view_deg, flee_health_threshold, patrol_speed_fraction, combat_speed_fraction
	## combat_config: optimal_weapon_range, base_accuracy, weapon_burst_rate, combat_speed_fraction

	# Skip if this is a player drone
	if is_in_group("player"):
		return

	# Switch input controller to AI mode
	if input_controller:
		input_controller.control_mode = 1  # AI mode

	# Check if OrchestratorAI already exists in the scene
	var orchestrator = get_node_or_null("OrchestratorAI")
	if not orchestrator:
		# Create orchestrator AI
		var OrchestratorAIScript = preload("res://src/ai/drone/drone_orchestrator_ai.gd")
		orchestrator = OrchestratorAIScript.new()
		orchestrator.name = "OrchestratorAI"
		orchestrator.drone = self
		add_child(orchestrator)

	# Configure AI with drone-specific settings
	orchestrator.configure(orchestrator_config)

	# Configure combat AI (queued by the orchestrator if CombatAI is not
	# created yet - it is built in a deferred callback)
	orchestrator.configure_combat(combat_config)
