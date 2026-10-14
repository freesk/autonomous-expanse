extends Node
class_name MotionSystem

## Motion System for Hover Drones
## Handles hover physics, movement, rotation, and boost
## Uses spring-damper suspension system with realistic forces
## This system works with a parent RigidBody3D

## Signals
signal boost_changed(boost_amount: float)
signal altitude_changed(altitude: float)
signal grounded_state_changed(is_grounded: bool)

## Hover Suspension System
@export_group("Hover System")
@export var hover_height: float = 3.0  ## Target height above ground (meters)
@export var hover_spring_strength: float = 8000.0  ## Spring force (N/m) per hover point
@export var hover_damping: float = 2000.0  ## Damping coefficient (N·s/m) per hover point
@export var num_hover_points: int = 4  ## Number of hover engines
@export var hover_point_radius: float = 1.0  ## Distance from center to hover points
@export var max_raycast_distance: float = 50.0  ## Maximum distance to check for ground
@export var landing_assist_height: float = 6.0  ## Height at which landing assist begins
@export var landing_assist_strength: float = 0.7  ## Strength of landing deceleration (0-1)

## Movement Forces (configured via initialize())
var thrust_force: float = 0.0  ## Forward/backward thrust (Newtons)
var strafe_force: float = 0.0  ## Left/right thrust (Newtons)
var climb_force: float = 0.0  ## Up/down thrust (Newtons)
var turn_torque: float = 0.0  ## Rotation torque (N·m)
var jump_impulse: float = 0.0  ## Instant upward impulse (N·s)
var jump_cooldown: float = 0.35  ## Time between jumps (seconds)

## Physics Properties (configured via initialize())
var drone_mass: float = 0.0  ## Mass in kg
var air_drag: float = 0.0  ## Linear drag coefficient
var rotation_drag: float = 2.0  ## Angular drag coefficient

## Boost System (configured via initialize())
var boost_multiplier: float = 0.0  ## Thrust multiplier when boosting
var boost_duration: float = 0.0  ## Seconds of boost available
var boost_cooldown: float = 0.0  ## Cooldown after depleted

## Visual Bobbing
@export_group("Buoyancy Animation")
@export var buoyancy_amplitude: float = 0.04  ## How much to bob
@export var buoyancy_frequency: float = 0.5  ## How fast to bob (Hz)

## Drone Rotation Control
@export_group("Rotation Control")
@export var aim_rotation_torque_multiplier: float = 3.5  ## Drone follow speed toward aim
@export var aim_rotation_deadzone_deg: float = 2.2  ## No corrective torque inside this yaw error
@export var aim_rotation_slow_zone_deg: float = 16.0  ## Reduce turn torque as we approach target
@export var aim_rotation_damping: float = 1.2  ## Angular velocity damping for yaw stabilization
@export var aim_settle_angular_speed: float = 0.08  ## Below this speed in deadzone, lock yaw to zero

## State Variables
var hover_raycasts: Array[RayCast3D] = []
var boost_available: float = 1.0  ## 0.0 to 1.0 (deprecated - energy system handles this now)
var boost_cooldown_timer: float = 0.0
var is_boosting: bool = false
var jump_cooldown_timer: float = 0.0
var buoyancy_time: float = 0.0
var is_grounded: bool = false
var current_altitude: float = 0.0

## Component References (set by parent)
var rigid_body: RigidBody3D = null
var model_mount: Node3D = null
var input_controller = null
var aim_system = null
var weapon_controller = null
var energy_system = null


func _ready() -> void:
	# Find parent RigidBody3D
	rigid_body = get_parent() as RigidBody3D
	if not rigid_body:
		push_error("[MotionSystem] Parent must be a RigidBody3D!")
		return


## Initialize motion system with stats from drone class
## Called by BaseDrone after components are created
func initialize(config: Dictionary) -> void:
	# Movement forces
	thrust_force = config.get("thrust_force", 0.0)
	strafe_force = config.get("strafe_force", 0.0)
	climb_force = config.get("climb_force", 0.0)
	turn_torque = config.get("turn_torque", 0.0)
	jump_impulse = config.get("jump_impulse", 0.0)

	# Physics properties
	drone_mass = config.get("drone_mass", 0.0)
	air_drag = config.get("air_drag", 0.0)
	rotation_drag = config.get("rotation_drag", 2.0)

	# Boost system
	boost_multiplier = config.get("boost_multiplier", 0.0)
	boost_duration = config.get("boost_duration", 0.0)
	boost_cooldown = config.get("boost_cooldown", 0.0)

	# Apply physics properties to RigidBody3D
	if rigid_body:
		rigid_body.mass = drone_mass
		rigid_body.gravity_scale = 1.0
		rigid_body.continuous_cd = true
		rigid_body.can_sleep = false
		rigid_body.linear_damp = air_drag
		rigid_body.angular_damp = rotation_drag

	# Setup hover raycasts
	setup_hover_raycasts()

	# Find ModelMount for visual bobbing
	model_mount = rigid_body.get_node_or_null("ModelMount") if rigid_body else null

	# Find components
	_find_components()


func setup_hover_raycasts() -> void:
	## Create raycast sensors for hover suspension
	if not rigid_body:
		return

	var positions: Array[Vector3] = []

	if num_hover_points == 4:
		positions = [
			Vector3(-hover_point_radius, -1.5, -hover_point_radius),
			Vector3(hover_point_radius, -1.5, -hover_point_radius),
			Vector3(-hover_point_radius, -1.5, hover_point_radius),
			Vector3(hover_point_radius, -1.5, hover_point_radius)
		]
	elif num_hover_points == 1:
		positions = [Vector3.ZERO]

	for pos in positions:
		var raycast = RayCast3D.new()
		raycast.position = pos
		raycast.target_position = Vector3(0, -max_raycast_distance, 0)
		raycast.enabled = true
		raycast.collision_mask = 1
		raycast.collide_with_bodies = true
		raycast.collide_with_areas = false
		raycast.hit_from_inside = false
		raycast.add_exception(rigid_body)
		rigid_body.add_child(raycast)
		hover_raycasts.append(raycast)


func _find_components() -> void:
	## Find component nodes on parent
	if not rigid_body:
		return

	input_controller = rigid_body.get_node_or_null("MotionController")
	aim_system = rigid_body.get_node_or_null("AimSystem")
	weapon_controller = rigid_body.get_node_or_null("WeaponController")
	energy_system = rigid_body.get_node_or_null("EnergySystem")


func _physics_process(delta: float) -> void:
	if not rigid_body:
		return

	# Update timers
	update_timers(delta)

	# Apply hover suspension forces
	apply_hover_suspension_forces()

	# Apply visual bobbing (non-physics)
	apply_buoyancy_bobbing(delta)

	# Handle movement from MotionController
	if input_controller:
		apply_movement_forces()
		handle_boost_input()
		handle_weapon_firing(delta)

	# Handle rotation
	if input_controller:
		if input_controller.control_mode == 0 and aim_system:
			# Player mode: rotate toward aim system target
			rotate_drone_toward_aim()
		elif input_controller.control_mode == 1:
			# AI mode: rotate toward AI look target
			rotate_drone_toward_target(input_controller.ai_look_target)


func apply_hover_suspension_forces() -> void:
	## Real spring-damper suspension system
	if not rigid_body:
		return

	var dt := get_physics_process_delta_time()
	var total_distance: float = 0.0
	var total_target_distance: float = 0.0
	var colliding_count: int = 0

	for raycast in hover_raycasts:
		raycast.force_raycast_update()

		if not raycast.is_colliding():
			continue

		var collision_point := raycast.get_collision_point()
		var ground_distance := raycast.global_position.distance_to(collision_point)
		total_distance += ground_distance
		colliding_count += 1

		var sensor_offset_down := maxf(0.0, -raycast.position.y)
		var target_distance := maxf(0.1, hover_height - sensor_offset_down)
		total_target_distance += target_distance

		# Spring force
		var compression := target_distance - ground_distance
		var spring_acceleration := (compression * hover_spring_strength) / rigid_body.mass

		# Damper force
		var damper_acceleration := 0.0
		if (compression > 0 and rigid_body.linear_velocity.y < 0) or (compression < 0 and rigid_body.linear_velocity.y > 0):
			damper_acceleration = (-rigid_body.linear_velocity.y * hover_damping * 0.3) / rigid_body.mass

		var total_acceleration := spring_acceleration + damper_acceleration
		var impulse := Vector3.UP * total_acceleration * dt
		rigid_body.apply_central_impulse(impulse)

	# Update grounded state
	var was_grounded := is_grounded
	is_grounded = colliding_count > 0
	if was_grounded != is_grounded:
		grounded_state_changed.emit(is_grounded)

	# If NO raycasts hit ground, apply strong downward force
	if colliding_count == 0:
		var gravity_force := Vector3.DOWN * (rigid_body.mass * 9.8)
		var damping_force := Vector3.DOWN * rigid_body.linear_velocity.y * air_drag * 2.0
		rigid_body.apply_central_force(gravity_force + damping_force)

	# Landing assist
	if colliding_count > 0 and rigid_body.linear_velocity.y < -1.0:
		var avg_distance = total_distance / float(colliding_count)
		current_altitude = avg_distance
		altitude_changed.emit(current_altitude)

		if avg_distance < landing_assist_height:
			var proximity := clampf(1.0 - (avg_distance / landing_assist_height), 0.0, 1.0)
			var assist_factor := proximity * proximity
			var extra_damping := -rigid_body.linear_velocity.y * hover_damping * assist_factor * landing_assist_strength * 2.0
			var damping_impulse := Vector3.UP * extra_damping * dt / rigid_body.mass
			rigid_body.apply_central_impulse(damping_impulse)


func apply_buoyancy_bobbing(delta: float) -> void:
	## Visual bobbing animation (ModelMount only)
	if not model_mount or not rigid_body:
		return

	buoyancy_time += delta
	var speed: float = rigid_body.linear_velocity.length()
	var buoyancy_strength: float = clampf(1.0 - (speed / 20.0), 0.3, 1.0)

	var roll_bob := sin(buoyancy_time * buoyancy_frequency * TAU) * buoyancy_amplitude
	var pitch_bob := sin(buoyancy_time * buoyancy_frequency * 0.7 * TAU) * buoyancy_amplitude * 0.8
	var vertical_bob := sin(buoyancy_time * buoyancy_frequency * 1.3 * TAU) * buoyancy_amplitude * 0.5

	model_mount.rotation.x = roll_bob * buoyancy_strength
	model_mount.rotation.z = pitch_bob * buoyancy_strength
	model_mount.position.y = vertical_bob * buoyancy_strength


func apply_movement_forces() -> void:
	## Apply thrust forces from MotionController
	if not input_controller or not rigid_body:
		return

	var input_dir := Vector3.ZERO
	input_dir.z = input_controller.movement_input.y  # Forward/back
	input_dir.x = input_controller.movement_input.x  # Strafe
	input_dir.y = input_controller.climb_input  # Vertical

	var jumped_this_frame: bool = false

	# Handle jump impulse
	if input_controller.wants_jump and jump_cooldown_timer <= 0.0:
		if energy_system and energy_system.has_energy(EnergySystem.JUMP_ENERGY_COST):
			if energy_system.consume_energy(EnergySystem.JUMP_ENERGY_COST):
				rigid_body.apply_central_impulse(Vector3.UP * jump_impulse)
				jump_cooldown_timer = jump_cooldown
				jumped_this_frame = true

	# Calculate thrust in world space
	var drone_forward := -rigid_body.global_transform.basis.z
	var drone_right := rigid_body.global_transform.basis.x

	drone_forward.y = 0
	drone_right.y = 0
	drone_forward = drone_forward.normalized()
	drone_right = drone_right.normalized()

	var thrust := Vector3.ZERO
	thrust += drone_forward * input_dir.z * thrust_force
	thrust += drone_right * input_dir.x * strafe_force

	# Vertical thrust with energy drain
	if input_dir.y > 0:  # Flying up
		if not jumped_this_frame:
			if energy_system:
				if energy_system.consume_energy_continuous(EnergySystem.FLY_UP_ENERGY_COST_PER_SECOND, get_physics_process_delta_time()):
					thrust += Vector3.UP * input_dir.y * climb_force
			else:
				thrust += Vector3.UP * input_dir.y * climb_force
	else:
		thrust += Vector3.UP * input_dir.y * climb_force

	# Apply boost multiplier
	if is_boosting and boost_available > 0.0:
		thrust *= boost_multiplier

	rigid_body.apply_central_force(thrust)


func handle_boost_input() -> void:
	## Check if boosting - uses energy system
	if not input_controller:
		return

	# Try to boost if player wants it and has energy
	if input_controller.wants_boost:
		if energy_system and energy_system.consume_energy_continuous(EnergySystem.BOOST_ENERGY_COST_PER_SECOND, get_physics_process_delta_time()):
			is_boosting = true
		else:
			is_boosting = false
	else:
		is_boosting = false


func handle_weapon_firing(delta: float) -> void:
	## Handle weapon firing logic
	if not weapon_controller or not input_controller:
		return

	# Update weapon aim target (ONLY if player drone with AimSystem)
	if aim_system and input_controller.is_player_controlled():
		weapon_controller.set_aim_target(aim_system.get_aim_position())

	# Handle firing
	var fired: bool = weapon_controller.handle_weapon_input(
		input_controller.wants_fire_primary,
		input_controller.wants_fire_secondary
	)

	# Notify aim system of firing
	if fired and aim_system:
		aim_system.on_weapon_fired()


func rotate_drone_toward_aim() -> void:
	## Rotate drone toward aim target (yaw only)
	if not aim_system or not rigid_body:
		return

	var target_yaw: float = aim_system.get_aim_target_yaw()
	_apply_yaw_control(Vector3(sin(target_yaw), 0, cos(target_yaw)))


func rotate_drone_toward_target(target_pos: Vector3) -> void:
	## Rotate AI drone toward target position (yaw only)
	if not rigid_body or target_pos == Vector3.ZERO:
		return

	var to_target := target_pos - rigid_body.global_position
	to_target.y = 0
	if to_target.length_squared() < 0.01:
		return

	_apply_yaw_control(to_target.normalized())


func _apply_yaw_control(desired_dir: Vector3) -> void:
	## Damped yaw controller. Instead of torque proportional to the raw angle
	## error (an undamped oscillator that wobbles around the target), this
	## drives the yaw RATE toward a rate proportional to the remaining angle:
	## the drone turns fast when far off, eases in through the slow zone, and
	## locks still inside the deadzone instead of overshooting back and forth.
	var current_forward := -rigid_body.global_transform.basis.z
	current_forward.y = 0
	if current_forward.length_squared() < 0.0001 or desired_dir.length_squared() < 0.0001:
		return
	current_forward = current_forward.normalized()

	var angle := current_forward.signed_angle_to(desired_dir.normalized(), Vector3.UP)
	var yaw_rate := rigid_body.angular_velocity.y
	var deadzone := deg_to_rad(aim_rotation_deadzone_deg)

	# Settled: on target and barely rotating -> hold still
	if absf(angle) <= deadzone and absf(yaw_rate) <= aim_settle_angular_speed:
		rigid_body.angular_velocity.y = 0.0
		return

	# Desired yaw rate: max speed outside the slow zone, ramping linearly to
	# zero through it; no corrective rotation requested inside the deadzone
	var desired_rate := 0.0
	if absf(angle) > deadzone:
		var slow_zone := maxf(deg_to_rad(aim_rotation_slow_zone_deg), 0.001)
		desired_rate = clampf(angle / slow_zone, -1.0, 1.0) * aim_rotation_torque_multiplier

	# Torque toward the desired rate (velocity servo). Because torque opposes
	# any rate above the desired one, the heading cannot be overshot the way
	# a pure angle-proportional torque overshoots it.
	var rate_error := desired_rate - yaw_rate
	rigid_body.apply_torque(Vector3.UP * rate_error * turn_torque * aim_rotation_damping)


func update_timers(delta: float) -> void:
	## Update cooldown timers
	if jump_cooldown_timer > 0.0:
		jump_cooldown_timer -= delta


func get_altitude() -> float:
	## Returns average altitude above ground from all hover raycasts
	var total_distance := 0.0
	var valid_casts := 0

	for raycast in hover_raycasts:
		if raycast.is_colliding():
			var ground_distance := raycast.global_position.distance_to(
				raycast.get_collision_point()
			)
			total_distance += ground_distance
			valid_casts += 1

	if valid_casts > 0:
		return total_distance / float(valid_casts)
	return 0.0


## Terminal horizontal speed at full throttle, from this drone's configured
## physics. 0.0 means physics not initialized yet.
func get_max_horizontal_speed() -> float:
	return SquadCohesionBrain.max_horizontal_speed(thrust_force, drone_mass, air_drag)


## AI Control Interface (for compatibility)
func set_ai_movement(move: Vector2, climb: float = 0.0) -> void:
	if input_controller:
		input_controller.set_ai_movement(move, climb)


func set_ai_fire(primary: bool, secondary: bool = false) -> void:
	if input_controller:
		input_controller.set_ai_fire(primary, secondary)


func set_ai_boost(enabled: bool) -> void:
	if input_controller:
		input_controller.set_ai_boost(enabled)


func set_ai_weapon_target(target_pos: Vector3) -> void:
	if weapon_controller:
		weapon_controller.set_aim_target(target_pos)
