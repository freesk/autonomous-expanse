extends Node
class_name EnergySystem

## Energy Management System for Drones
## Handles energy consumption for weapons, abilities, and boosting
## Energy regenerates over time

signal energy_changed(current: float, maximum: float)
signal energy_depleted()
signal energy_regeneration_started()
signal energy_regeneration_stopped()

## Maximum Values
@export var max_energy: float = 100.0

## Current Values
var current_energy: float = 100.0

## Energy Regeneration
var energy_regen_rate: float = 20.0  # Energy per second (varies by drone)
@export var energy_regen_delay: float = 0.0  # Seconds after consumption before regen starts (0 = instant for responsive gameplay)
@export var energy_regen_enabled: bool = true

var time_since_last_consumption: float = 0.0
var is_regenerating_energy: bool = false

## Energy Consumption Rates (per DRONE_PHYSICS_SPEC.md)
## These are constants as they are the same across all drones
const BOOST_ENERGY_COST_PER_SECOND: float = 33.3  # Same for all drones
const JUMP_ENERGY_COST: float = 20.0  # Instant cost
const FLY_UP_ENERGY_COST_PER_SECOND: float = 15.0  # Continuous drain


func _ready() -> void:
	current_energy = max_energy


## Initialize energy system with stats from drone class
## Called by child drone classes
func initialize(config: Dictionary) -> void:
	max_energy = config.get("max_energy", 100.0)
	energy_regen_rate = config.get("energy_regen_rate", 20.0)

	# Reset current value to match new max
	current_energy = max_energy

	# Emit initial state
	energy_changed.emit(current_energy, max_energy)


func _process(delta: float) -> void:
	# Track time since last consumption for energy regen
	if time_since_last_consumption < energy_regen_delay:
		time_since_last_consumption += delta

		# Start regeneration when delay is reached
		if time_since_last_consumption >= energy_regen_delay and not is_regenerating_energy:
			_start_energy_regeneration()
	elif energy_regen_delay <= 0.0 and not is_regenerating_energy:
		# Instant regen if delay is 0 (for AI drones)
		_start_energy_regeneration()

	# Regenerate energy
	if is_regenerating_energy and energy_regen_enabled:
		var regen_amount: float = energy_regen_rate * delta
		current_energy = min(current_energy + regen_amount, max_energy)
		energy_changed.emit(current_energy, max_energy)

		# Stop regenerating when energy is full
		if current_energy >= max_energy:
			_stop_energy_regeneration()


## Energy Consumption
func consume_energy(amount: float) -> bool:
	if amount <= 0:
		return true

	if current_energy < amount:
		energy_depleted.emit()
		return false

	current_energy -= amount
	current_energy = max(current_energy, 0)
	energy_changed.emit(current_energy, max_energy)

	# Reset regeneration timer
	time_since_last_consumption = 0.0
	if is_regenerating_energy:
		_stop_energy_regeneration()

	return true


func has_energy(amount: float) -> bool:
	return current_energy >= amount


func consume_energy_continuous(rate_per_second: float, delta: float) -> bool:
	## Consume energy continuously at the given rate
	## Returns true if energy was consumed, false if insufficient
	var amount = rate_per_second * delta
	return consume_energy(amount)


## Restore Energy
func restore_energy(amount: float) -> void:
	if amount <= 0:
		return

	current_energy = min(current_energy + amount, max_energy)
	energy_changed.emit(current_energy, max_energy)


func restore_full() -> void:
	current_energy = max_energy
	energy_changed.emit(current_energy, max_energy)


## Energy Regeneration Control
func _start_energy_regeneration() -> void:
	if current_energy >= max_energy:
		return

	is_regenerating_energy = true
	energy_regeneration_started.emit()


func _stop_energy_regeneration() -> void:
	is_regenerating_energy = false
	energy_regeneration_stopped.emit()


func enable_energy_regeneration() -> void:
	energy_regen_enabled = true


func disable_energy_regeneration() -> void:
	energy_regen_enabled = false
	_stop_energy_regeneration()


## Status Queries
func get_energy_percentage() -> float:
	if max_energy <= 0.0:
		return 0.0
	return (current_energy / max_energy) * 100.0


func is_energy_full() -> bool:
	return current_energy >= max_energy


func is_energy_empty() -> bool:
	return current_energy <= 0


## Max Value Modifiers (for upgrades)
func increase_max_energy(amount: float) -> void:
	max_energy += amount
	current_energy = min(current_energy, max_energy)
	energy_changed.emit(current_energy, max_energy)


func set_energy_regen_rate(rate: float) -> void:
	energy_regen_rate = rate


func set_energy_regen_delay(delay: float) -> void:
	energy_regen_delay = delay
