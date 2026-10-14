extends Node
class_name HealthSystem

## Health and Shield Management System
## Handles damage application, shield regeneration, and death
## Shields absorb damage first, then health
## Shields regenerate after 10 seconds of not taking damage

signal health_changed(current: float, maximum: float)
signal shields_changed(current: float, maximum: float)
signal damage_taken(amount: float, attacker: Node3D)
signal shield_depleted()
signal shield_regeneration_started()
signal shield_regeneration_stopped()
signal died()

## Maximum Values (set via initialize() from drone classes)
var max_health: float = 100.0
var max_shields: float = 100.0

## Current Values
var current_health: float = 100.0
var current_shields: float = 100.0

## Shield Regeneration (set via initialize() from drone classes)
var shield_regen_delay: float = 10.0  # Seconds after last hit before regen starts
var shield_regen_rate: float = 10.0  # Shields per second when regenerating
@export var shield_regen_enabled: bool = true

var time_since_last_damage: float = 0.0
var is_regenerating_shields: bool = false
var is_alive: bool = true


func _ready() -> void:
	current_health = max_health
	current_shields = max_shields
	is_alive = true


## Initialize health system with stats from drone class
## Called by child drone classes
func initialize(config: Dictionary) -> void:
	max_health = config.get("max_health", 100.0)
	max_shields = config.get("max_shields", 100.0)
	shield_regen_rate = config.get("shield_regen_rate", 10.0)
	shield_regen_delay = config.get("shield_regen_delay", 10.0)

	# Reset current values to match new maxes
	current_health = max_health
	current_shields = max_shields

	# Emit initial state
	health_changed.emit(current_health, max_health)
	shields_changed.emit(current_shields, max_shields)


func _process(delta: float) -> void:
	if not is_alive:
		return

	# Track time since last damage for shield regen
	if time_since_last_damage < shield_regen_delay:
		time_since_last_damage += delta

		# Start regeneration when delay is reached
		if time_since_last_damage >= shield_regen_delay and not is_regenerating_shields:
			_start_shield_regeneration()

	# Regenerate shields
	if is_regenerating_shields and shield_regen_enabled:
		var regen_amount: float = shield_regen_rate * delta
		current_shields = min(current_shields + regen_amount, max_shields)
		shields_changed.emit(current_shields, max_shields)

		# Stop regenerating when shields are full
		if current_shields >= max_shields:
			_stop_shield_regeneration()


## Damage Application
## All damage in this game is energy-based (lasers)
func take_damage(amount: float, attacker: Node3D = null) -> void:
	if not is_alive or amount <= 0:
		return

	# Check if player attacked this faction drone
	_check_player_attack(attacker)

	# Apply standard damage (shields first, then health)
	_apply_standard_damage(amount)

	# Emit signal with attacker info
	damage_taken.emit(amount, attacker)

	# Reset shield regeneration timer
	time_since_last_damage = 0.0
	if is_regenerating_shields:
		_stop_shield_regeneration()

	# Check if dead
	if current_health <= 0:
		_die()


## Check if player attacked a faction drone and update faction relations
func _check_player_attack(attacker: Node3D) -> void:
	if not attacker:
		return

	# Check if attacker is the player
	if not attacker.is_in_group("player"):
		return

	# Get the parent drone (this HealthSystem is a child of the drone)
	var drone = get_parent()
	if not drone:
		return

	# Try multiple ways to get faction_id
	var faction_id: int = -1

	# Method 1: Direct property
	if "faction_id" in drone:
		faction_id = drone.faction_id
	# Method 2: Check metadata
	elif drone.has_meta("faction_id"):
		faction_id = drone.get_meta("faction_id")
	# Method 3: Check if drone has OrchestratorAI with parent squad
	else:
		var orchestrator = drone.get_node_or_null("OrchestratorAI")
		if orchestrator and "parent_squad" in orchestrator and orchestrator.parent_squad:
			var squad = orchestrator.parent_squad
			if "faction_id" in squad:
				faction_id = squad.faction_id

	if faction_id < 0:
		print("[HealthSystem] Could not determine faction_id for drone: %s" % drone.name)
		return

	print("[HealthSystem] Player attacked drone from faction %d!" % faction_id)

	# Get the faction and mark it as hostile to player
	var faction_mgr = FactionManager.instance
	if not faction_mgr:
		print("[HealthSystem] FactionManager not found!")
		return

	var faction = faction_mgr.get_faction(faction_id)
	if not faction:
		print("[HealthSystem] Faction %d not found!" % faction_id)
		return

	if not faction.is_hostile_to_player():
		print("[HealthSystem] ✓ Faction %d (%s) is now HOSTILE to player!" % [faction_id, faction.faction_name])
		faction.set_hostile_to_player()
	else:
		print("[HealthSystem] Faction %d already hostile to player" % faction_id)


func _apply_standard_damage(damage: float) -> void:
	# Shields absorb damage first
	if current_shields > 0:
		var shield_damage: float = min(damage, current_shields)
		current_shields -= shield_damage
		damage -= shield_damage
		shields_changed.emit(current_shields, max_shields)

		if current_shields <= 0:
			current_shields = 0
			shield_depleted.emit()

	# Remaining damage goes to health
	if damage > 0:
		current_health -= damage
		current_health = max(current_health, 0)
		health_changed.emit(current_health, max_health)


## Healing
func heal(amount: float) -> void:
	if not is_alive or amount <= 0:
		return

	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)


func restore_shields(amount: float) -> void:
	if not is_alive or amount <= 0:
		return

	current_shields = min(current_shields + amount, max_shields)
	shields_changed.emit(current_shields, max_shields)


func restore_full() -> void:
	current_health = max_health
	current_shields = max_shields
	health_changed.emit(current_health, max_health)
	shields_changed.emit(current_shields, max_shields)
	is_alive = true


## Shield Regeneration Control
func _start_shield_regeneration() -> void:
	if current_shields >= max_shields:
		return

	is_regenerating_shields = true
	shield_regeneration_started.emit()


func _stop_shield_regeneration() -> void:
	is_regenerating_shields = false
	shield_regeneration_stopped.emit()


func enable_shield_regeneration() -> void:
	shield_regen_enabled = true


func disable_shield_regeneration() -> void:
	shield_regen_enabled = false
	_stop_shield_regeneration()


## Death
func _die() -> void:
	if not is_alive:
		return

	is_alive = false
	current_health = 0

	# Log player destruction for REQUIREMENT 3
	var parent_node = get_parent()
	if parent_node and parent_node.is_in_group("player"):
		print("[HealthSystem] ✓ REQUIREMENT 3: PLAYER DESTROYED by AI!")

	died.emit()


func revive() -> void:
	restore_full()
	is_alive = true


## Status Queries
func is_dead() -> bool:
	return not is_alive


func get_health_percentage() -> float:
	if max_health <= 0.0:
		return 0.0
	return (current_health / max_health) * 100.0


func get_shields_percentage() -> float:
	if max_shields <= 0.0:
		return 0.0
	return (current_shields / max_shields) * 100.0


func has_shields() -> bool:
	return current_shields > 0


## Max Value Modifiers (for upgrades)
func increase_max_health(amount: float) -> void:
	max_health += amount
	current_health = min(current_health, max_health)
	health_changed.emit(current_health, max_health)


func increase_max_shields(amount: float) -> void:
	max_shields += amount
	current_shields = min(current_shields, max_shields)
	shields_changed.emit(current_shields, max_shields)


func set_shield_regen_rate(rate: float) -> void:
	shield_regen_rate = rate


func set_shield_regen_delay(delay: float) -> void:
	shield_regen_delay = delay
