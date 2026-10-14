extends Node3D
class_name WeaponBase

## Base class for all weapon systems in DroneWorld
## ENERGY-BASED ONLY: No ammo, no heat, only energy consumption
## All weapons use the drone's energy pool

## Weapon identification
@export var weapon_name: String = "Base Weapon"
@export var weapon_type: String = "laser"  # laser or energy_burst ONLY

## Damage properties
@export var base_damage: float = 10.0
@export var damage_type: String = "energy"  # ALWAYS "energy" - no other damage types

## Fire rate and timing
@export var fire_rate: float = 5.0  # shots per second (for burst) or DPS (for laser)
@export var burst_size: int = 1  # shots per burst (for energy_burst)
@export var burst_delay: float = 0.1  # delay between burst shots

## Range and accuracy
@export var max_range: float = 300.0
@export var accuracy: float = 0.85  # 0.0 to 1.0
@export var projectile_speed: float = 500.0  # for energy_burst only

## Energy consumption
@export var energy_cost_per_shot: float = 10.0  # energy per shot
@export var energy_cost_per_second: float = 20.0  # for continuous weapons (lasers)

## Physical properties
@export var weight: float = 10.0

## Internal state
var is_firing: bool = false
var time_since_last_shot: float = 0.0
var shots_in_burst: int = 0
var has_aim_target: bool = false
var aim_target_position: Vector3 = Vector3.ZERO

## References
var owner_drone: Node3D
var muzzle_point: Node3D

## Signals
signal fired(weapon)
signal hit_target(target: Node3D, damage: float, hit_position: Vector3)
signal energy_depleted()

func _ready() -> void:
	# Find muzzle point if it exists
	muzzle_point = find_child("MuzzlePoint", false, false)
	if not muzzle_point:
		muzzle_point = self

func _process(delta: float) -> void:
	# Update fire rate timer
	if time_since_last_shot < get_fire_interval():
		time_since_last_shot += delta

	# Continuous energy drain for lasers while firing
	if is_firing and weapon_type == "laser" and owner_drone:
		var energy_system = owner_drone.get_node_or_null("EnergySystem")
		if energy_system:
			if not energy_system.consume_energy_continuous(energy_cost_per_second, delta):
				# Out of energy, stop firing
				is_firing = false
				energy_depleted.emit()

## Returns the time between shots based on fire rate
func get_fire_interval() -> float:
	return 1.0 / fire_rate

## Attempt to fire the weapon
func try_fire() -> bool:
	if not can_fire():
		return false

	# Check burst mode
	if burst_size > 1:
		if shots_in_burst == 0:
			# Start new burst
			_fire_shot()
			shots_in_burst = 1
			return true
		elif shots_in_burst < burst_size and time_since_last_shot >= burst_delay:
			# Continue burst
			_fire_shot()
			shots_in_burst += 1
			if shots_in_burst >= burst_size:
				shots_in_burst = 0
			return true
	else:
		# Single shot mode
		_fire_shot()
		return true

	return false

## Check if weapon can fire
func can_fire() -> bool:
	# Check fire rate
	if time_since_last_shot < get_fire_interval():
		return false

	# Check if drone has enough energy via EnergySystem
	if owner_drone:
		var energy_system = owner_drone.get_node_or_null("EnergySystem")
		if energy_system:
			# Laser energy is consumed over time, approximated as per-shot chunks.
			var energy_needed = energy_cost_per_shot if weapon_type == "energy_burst" else energy_cost_per_second * get_fire_interval()
			if not energy_system.has_energy(energy_needed):
				energy_depleted.emit()
				return false

	return true

## Internal fire implementation
func _fire_shot() -> void:
	# Consume energy from EnergySystem
	if owner_drone:
		var energy_system = owner_drone.get_node_or_null("EnergySystem")
		if energy_system:
			var energy_to_consume = energy_cost_per_shot if weapon_type == "energy_burst" else energy_cost_per_second * get_fire_interval()
			energy_system.consume_energy(energy_to_consume)

	# Reset fire timer
	time_since_last_shot = 0.0

	# Call implementation-specific fire method
	fire()

	# Emit signal
	fired.emit(self)

## Override this method in derived classes
func fire() -> void:
	push_warning("WeaponBase.fire() called - should be overridden in derived class")

## Get weapon origin point for firing
func get_fire_origin() -> Vector3:
	if muzzle_point:
		return muzzle_point.global_position
	return global_position

## Get weapon fire direction
func get_fire_direction() -> Vector3:
	var origin := get_fire_origin()
	if has_aim_target:
		var to_target := aim_target_position - origin
		if to_target.length_squared() > 0.0001:
			return to_target.normalized()

	if muzzle_point:
		return -muzzle_point.global_transform.basis.z
	return -global_transform.basis.z

## Set a world-space aim target (from player reticle/camera ray)
func set_aim_target(target: Vector3) -> void:
	aim_target_position = target
	has_aim_target = true

## Clear aim override
func clear_aim_target() -> void:
	has_aim_target = false

## Apply spread to direction based on accuracy
func apply_spread(direction: Vector3) -> Vector3:
	var spread_angle = deg_to_rad((1.0 - accuracy) * 10.0)  # Max 10 degrees at 0 accuracy
	var random_x = randf_range(-spread_angle, spread_angle)
	var random_y = randf_range(-spread_angle, spread_angle)

	# Create rotation basis
	var spread_basis = Basis()
	spread_basis = spread_basis.rotated(Vector3.UP, random_x)
	spread_basis = spread_basis.rotated(Vector3.RIGHT, random_y)

	return spread_basis * direction

## Calculate damage falloff based on distance
func calculate_distance_modifier(distance: float) -> float:
	if distance <= max_range * 0.5:
		return 1.0  # Full damage at close range
	elif distance <= max_range:
		# Linear falloff from 50% to 100% of max range
		var falloff_range = max_range * 0.5
		var falloff_distance = distance - (max_range * 0.5)
		return 1.0 - (falloff_distance / falloff_range) * 0.5  # 50% damage at max range
	else:
		return 0.1  # Minimal damage beyond max range

## Get current weapon stats for UI display
func get_weapon_stats() -> Dictionary:
	return {
		"name": weapon_name,
		"type": weapon_type,
		"damage": base_damage,
		"fire_rate": fire_rate,
		"range": max_range,
		"accuracy": accuracy,
		"energy_cost": energy_cost_per_shot if weapon_type == "energy_burst" else energy_cost_per_second,
		"is_firing": is_firing,
		"weight": weight
	}

## Apply weapon upgrade
func apply_upgrade(upgrade_type: String, modifier: float) -> void:
	match upgrade_type:
		"damage":
			base_damage *= modifier
		"fire_rate":
			fire_rate *= modifier
		"accuracy":
			accuracy = min(1.0, accuracy * modifier)
		"energy_efficiency":
			energy_cost_per_shot /= modifier
			energy_cost_per_second /= modifier
		"range":
			max_range *= modifier
		"weight":
			weight /= modifier

## Clean up
func _exit_tree() -> void:
	# Clear any active timers or effects
	pass
