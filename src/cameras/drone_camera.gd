class_name DroneCamera
extends Camera3D

## Third-person camera system for DroneWorld with adaptive smoothing and obstruction prevention
##
## Features:
## - Full manual control (rotation, tilt, zoom)
## - Adaptive smoothing (cruise vs combat modes)
## - Intelligent obstruction prevention
## - Smooth reset to default position
## - Mouse and gamepad input support

# Signals
signal combat_mode_changed(is_combat: bool)
signal camera_obstructed(is_obstructed: bool)

# Enums
enum CameraMode {
	CRUISE,    ## Low speed, cinematic camera
	COMBAT,    ## High speed or combat, responsive camera
	RESETTING  ## Returning to default position
}

# Constants
const MIN_DISTANCE: float = 1.5
const MAX_DISTANCE: float = 12.0
const DEFAULT_DISTANCE: float = 3.0
const MIN_TILT: float = -80.0
const MAX_TILT: float = 80.0
const DEFAULT_TILT: float = 15.0
const DEFAULT_VERTICAL_OFFSET: float = 1.5

const ZOOM_SPEED: float = 0.5
const ROTATION_SPEED: float = 180.0
const TILT_SPEED: float = 120.0

const CRUISE_POSITION_SMOOTHING: float = 0.3
const COMBAT_POSITION_SMOOTHING: float = 0.6
const CRUISE_ROTATION_SMOOTHING: float = 0.15
const COMBAT_ROTATION_SMOOTHING: float = 0.4

const COMBAT_TRANSITION_TIME: float = 0.5
const RESET_DURATION: float = 0.5
const MIN_SAFE_DISTANCE: float = 2.0
const COLLISION_OFFSET: float = 0.5

const DEFAULT_FOV: float = 75.0
const MIN_FOV: float = 60.0
const MAX_FOV: float = 90.0

# Export variables for customization
@export_group("Distance Settings")
@export var min_distance: float = MIN_DISTANCE
@export var max_distance: float = MAX_DISTANCE
@export var default_distance: float = DEFAULT_DISTANCE
@export var zoom_speed: float = ZOOM_SPEED

@export_group("Rotation Settings")
@export var rotation_speed: float = ROTATION_SPEED
@export var tilt_speed: float = TILT_SPEED
@export var min_tilt: float = MIN_TILT
@export var max_tilt: float = MAX_TILT
@export var invert_y: bool = false

@export_group("Smoothing Settings")
@export var cruise_position_smoothing: float = CRUISE_POSITION_SMOOTHING
@export var combat_position_smoothing: float = COMBAT_POSITION_SMOOTHING
@export var cruise_rotation_smoothing: float = CRUISE_ROTATION_SMOOTHING
@export var combat_rotation_smoothing: float = COMBAT_ROTATION_SMOOTHING

@export_group("Combat Detection")
@export var combat_speed_threshold: float = 20.0
@export var enemy_proximity_threshold: float = 50.0
@export var combat_decay_time: float = 2.0

@export_group("FOV Settings")
@export var base_fov: float = DEFAULT_FOV
@export var min_fov: float = MIN_FOV
@export var max_fov: float = MAX_FOV

@export_group("Sensitivity")
@export var mouse_sensitivity: float = 1.0
@export var gamepad_sensitivity: float = 1.0

@export_group("References")
@export var target_drone: Node3D = null

# Public variables
var current_mode: CameraMode = CameraMode.CRUISE
var is_obstructed: bool = false
var free_rotation_mode: bool = false  # True when middle mouse is held

# Private variables
var _desired_distance: float = DEFAULT_DISTANCE
var _current_distance: float = DEFAULT_DISTANCE
var _camera_rotation: float = 0.0  # Horizontal rotation (yaw)
var _camera_tilt: float = DEFAULT_TILT  # Vertical rotation (pitch)

var _combat_intensity: float = 0.0  # 0.0 = cruise, 1.0 = combat
var _combat_timer: float = 0.0
var _was_in_combat: bool = false

var _reset_progress: float = 0.0
var _reset_start_rotation: float = 0.0
var _reset_start_tilt: float = 0.0
var _reset_start_distance: float = 0.0

var _current_position_smoothing: float = CRUISE_POSITION_SMOOTHING
var _current_rotation_smoothing: float = CRUISE_ROTATION_SMOOTHING

var _last_weapon_fire_time: float = 0.0
var _last_damage_time: float = 0.0
var _drone_current_speed: float = 0.0

# Node references
@onready var _raycast: RayCast3D = RayCast3D.new()
@onready var _camera_pivot: Node3D = Node3D.new()


func _ready() -> void:
	# Auto-detect target drone if not set (find drone in scene)
	if not target_drone:
		# First check if target_drone_path is set (from @export var)
		var parent := get_parent()
		if parent:
			# Look for a node named "Player" or any RigidBody3D/CharacterBody3D
			for child in parent.get_children():
				if child.name == "Player":
					target_drone = child
					print("[DroneCamera] Found Player drone")
					break
				elif child is RigidBody3D or child is CharacterBody3D:
					target_drone = child
					print("[DroneCamera] Found drone: ", child.name)
					break

	if not target_drone:
		push_warning("DroneCamera: No target_drone found! Camera will not function.")
		return

	print("[DroneCamera] Locked onto: ", target_drone.name, " at ", target_drone.global_position)

	# Setup camera
	fov = base_fov

	# Setup pivot and camera positioning
	call_deferred("_setup_camera_system")

	# Capture mouse for camera control (always-on for now)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED



func _setup_camera_system() -> void:
	"""Setup camera pivot and raycast systems."""
	if not is_inside_tree() or not target_drone:
		return

	# Get the drone's current global position
	var drone_pos = target_drone.global_position

	# Add pivot to scene root
	var scene_root = get_parent()
	if scene_root and not _camera_pivot.is_inside_tree():
		scene_root.add_child(_camera_pivot)
	_camera_pivot.global_position = drone_pos

	# Setup raycast
	if not _raycast.is_inside_tree():
		add_child(_raycast)
	_raycast.enabled = true
	_raycast.exclude_parent = true
	_raycast.collision_mask = 1
	_raycast.hit_from_inside = false

	# Initialize camera position
	global_position = drone_pos + Vector3(0, DEFAULT_VERTICAL_OFFSET, -DEFAULT_DISTANCE)
	_update_camera_transform()


func _init_pivot_position() -> void:
	"""Initialize camera pivot position after it's been added to tree."""
	if _camera_pivot and is_inside_tree() and target_drone:
		_camera_pivot.global_position = target_drone.global_position


func _init_camera_position() -> void:
	"""Initialize camera position after everything is in the tree."""
	if target_drone and _camera_pivot and is_inside_tree():
		_camera_pivot.global_position = target_drone.global_position
		_update_camera_transform()


func _process(delta: float) -> void:
	if not target_drone:
		return

	# Update combat state
	_update_combat_state(delta)

	# Handle camera mode
	match current_mode:
		CameraMode.CRUISE, CameraMode.COMBAT:
			_handle_input(delta)
			_check_camera_collision()
			_apply_smoothing(delta)
			_update_camera_transform()

		CameraMode.RESETTING:
			_process_reset(delta)
			_check_camera_collision()
			_apply_smoothing(delta)
			_update_camera_transform()


func _input(event: InputEvent) -> void:
	# Mouse rotation input (always active when mouse captured)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_handle_mouse_motion(event)

	# Mouse zoom input
	if event is InputEventMouseButton:
		_handle_mouse_zoom(event)

	# Reset camera input
	if event.is_action_pressed("camera_reset"):
		reset_camera()

	# ESC to release mouse
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Handles mouse motion for camera rotation and tilt
func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if current_mode == CameraMode.RESETTING:
		# Interrupt reset on manual input
		current_mode = CameraMode.CRUISE if _combat_intensity < 0.5 else CameraMode.COMBAT

	var sensitivity: float = mouse_sensitivity * 0.1

	# Horizontal rotation
	_camera_rotation -= event.relative.x * sensitivity
	_camera_rotation = wrapf(_camera_rotation, 0.0, 360.0)

	# Vertical tilt
	var tilt_delta: float = -event.relative.y * sensitivity if not invert_y else event.relative.y * sensitivity
	_camera_tilt = clamp(_camera_tilt + tilt_delta, min_tilt, max_tilt)


## Handles mouse wheel zoom
func _handle_mouse_zoom(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_desired_distance = clamp(_desired_distance - zoom_speed, min_distance, max_distance)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_desired_distance = clamp(_desired_distance + zoom_speed, min_distance, max_distance)


## Handles keyboard and gamepad input for camera control
func _handle_input(delta: float) -> void:
	# Gamepad camera rotation
	var right_stick_x: float = Input.get_axis("camera_right", "camera_left")
	var right_stick_y: float = Input.get_axis("camera_down", "camera_up")

	if abs(right_stick_x) > 0.1 or abs(right_stick_y) > 0.1:
		var sensitivity: float = gamepad_sensitivity

		# Horizontal rotation
		_camera_rotation += right_stick_x * rotation_speed * sensitivity * delta
		_camera_rotation = wrapf(_camera_rotation, 0.0, 360.0)

		# Vertical tilt
		var tilt_delta: float = right_stick_y * tilt_speed * sensitivity * delta
		if invert_y:
			tilt_delta = -tilt_delta
		_camera_tilt = clamp(_camera_tilt + tilt_delta, min_tilt, max_tilt)

	# Gamepad zoom
	if Input.is_action_pressed("camera_zoom_in"):
		_desired_distance = clamp(_desired_distance - zoom_speed * delta * 10.0, min_distance, max_distance)
	if Input.is_action_pressed("camera_zoom_out"):
		_desired_distance = clamp(_desired_distance + zoom_speed * delta * 10.0, min_distance, max_distance)


## Updates combat state based on various factors
func _update_combat_state(delta: float) -> void:
	var was_intensity: float = _combat_intensity

	# Detect combat conditions
	var is_combat: bool = false

	# Speed threshold
	if _drone_current_speed > combat_speed_threshold:
		is_combat = true

	# Recent weapon fire
	if Time.get_ticks_msec() - _last_weapon_fire_time < 3000:  # 3 seconds
		is_combat = true

	# Recent damage
	if Time.get_ticks_msec() - _last_damage_time < 5000:  # 5 seconds
		is_combat = true

	# Enemy proximity (would need enemy manager integration)
	# TODO: Check for nearby enemies

	# Update combat intensity
	if is_combat:
		_combat_timer = combat_decay_time
		_combat_intensity = move_toward(_combat_intensity, 1.0, delta / COMBAT_TRANSITION_TIME)
	else:
		_combat_timer = max(0.0, _combat_timer - delta)
		if _combat_timer <= 0.0:
			_combat_intensity = move_toward(_combat_intensity, 0.0, delta / COMBAT_TRANSITION_TIME)

	# Update smoothing factors
	_current_position_smoothing = lerp(cruise_position_smoothing, combat_position_smoothing, _combat_intensity)
	_current_rotation_smoothing = lerp(cruise_rotation_smoothing, combat_rotation_smoothing, _combat_intensity)

	# Emit signal on mode change
	var is_now_combat: bool = _combat_intensity > 0.5
	if _was_in_combat != is_now_combat:
		_was_in_combat = is_now_combat
		current_mode = CameraMode.COMBAT if is_now_combat else CameraMode.CRUISE
		combat_mode_changed.emit(is_now_combat)


## Checks for camera collision and adjusts distance
func _check_camera_collision() -> void:
	if not target_drone:
		return

	# Calculate desired camera position
	var drone_pos: Vector3 = target_drone.global_position
	var offset: Vector3 = Vector3(0, DEFAULT_VERTICAL_OFFSET, 0)
	var ray_origin: Vector3 = drone_pos + offset

	# Calculate ray direction based on camera rotation and tilt
	var rotation_rad: float = deg_to_rad(_camera_rotation)
	var tilt_rad: float = deg_to_rad(_camera_tilt)

	var direction: Vector3 = Vector3(
		sin(rotation_rad) * cos(tilt_rad),
		-sin(tilt_rad),
		cos(rotation_rad) * cos(tilt_rad)
	).normalized()

	# Setup raycast
	_raycast.global_position = ray_origin
	_raycast.target_position = direction * _desired_distance
	_raycast.force_raycast_update()

	# Check for collision
	var was_obstructed: bool = is_obstructed
	if _raycast.is_colliding():
		var collision_point: Vector3 = _raycast.get_collision_point()
		var collision_distance: float = ray_origin.distance_to(collision_point)
		var safe_distance: float = max(collision_distance - COLLISION_OFFSET, MIN_SAFE_DISTANCE)
		_current_distance = min(safe_distance, _desired_distance)
		is_obstructed = true
	else:
		_current_distance = _desired_distance
		is_obstructed = false

	# Emit signal on obstruction change
	if was_obstructed != is_obstructed:
		camera_obstructed.emit(is_obstructed)


## Applies adaptive smoothing to camera movement
func _apply_smoothing(delta: float) -> void:
	if not target_drone:
		return

	# Smooth pivot position to follow drone
	var target_pos: Vector3 = target_drone.global_position
	_camera_pivot.global_position = _camera_pivot.global_position.lerp(
		target_pos,
		_current_position_smoothing
	)


## Updates camera transform based on current settings
func _update_camera_transform() -> void:
	if not target_drone:
		return

	# Preserve player-controlled camera yaw; aim system rotates drone to align.
	var rotation_rad: float = deg_to_rad(_camera_rotation)
	var tilt_rad: float = deg_to_rad(_camera_tilt)

	var direction: Vector3 = Vector3(
		sin(rotation_rad) * cos(tilt_rad),
		-sin(tilt_rad),
		cos(rotation_rad) * cos(tilt_rad)
	).normalized()

	var offset: Vector3 = Vector3(0, DEFAULT_VERTICAL_OFFSET, 0)
	var camera_target: Vector3 = _camera_pivot.global_position + offset + (direction * _current_distance)

	# Smooth camera position
	global_position = global_position.lerp(camera_target, _current_rotation_smoothing)

	# Look at drone with offset
	var look_target: Vector3 = _camera_pivot.global_position + offset
	look_at(look_target, Vector3.UP)


## Resets camera to default position with smooth animation
func reset_camera() -> void:
	current_mode = CameraMode.RESETTING
	_reset_progress = 0.0
	_reset_start_rotation = _camera_rotation
	_reset_start_tilt = _camera_tilt
	_reset_start_distance = _desired_distance


## Processes camera reset animation
func _process_reset(delta: float) -> void:
	if not target_drone:
		return

	_reset_progress += delta / RESET_DURATION

	if _reset_progress >= 1.0:
		# Reset complete
		_camera_rotation = 0.0
		_camera_tilt = DEFAULT_TILT
		_desired_distance = DEFAULT_DISTANCE
		current_mode = CameraMode.CRUISE if _combat_intensity < 0.5 else CameraMode.COMBAT
		_reset_progress = 0.0
		return

	# Smooth interpolation using ease-out
	var t: float = 1.0 - pow(1.0 - _reset_progress, 3.0)

	# Interpolate rotation (handle wrap-around)
	var target_rotation: float = 0.0
	var rotation_diff: float = target_rotation - _reset_start_rotation
	if abs(rotation_diff) > 180.0:
		if rotation_diff > 0:
			rotation_diff -= 360.0
		else:
			rotation_diff += 360.0
	_camera_rotation = _reset_start_rotation + (rotation_diff * t)
	_camera_rotation = wrapf(_camera_rotation, 0.0, 360.0)

	# Interpolate tilt
	_camera_tilt = lerp(_reset_start_tilt, DEFAULT_TILT, t)

	# Interpolate distance
	_desired_distance = lerp(_reset_start_distance, DEFAULT_DISTANCE, t)


## Notifies camera of weapon fire for combat detection
func on_weapon_fired() -> void:
	_last_weapon_fire_time = Time.get_ticks_msec()


## Notifies camera of damage taken for combat detection
func on_damage_taken() -> void:
	_last_damage_time = Time.get_ticks_msec()


## Updates drone speed for combat detection
func update_drone_speed(speed: float) -> void:
	_drone_current_speed = speed


## Sets the target drone for the camera to follow
func set_target_drone(drone: Node3D) -> void:
	target_drone = drone
	if target_drone and _camera_pivot:
		_camera_pivot.global_position = target_drone.global_position


## Gets the current camera mode
func get_camera_mode() -> CameraMode:
	return current_mode


## Gets the current combat intensity (0.0 to 1.0)
func get_combat_intensity() -> float:
	return _combat_intensity


## Sets FOV with clamping
func set_fov_value(new_fov: float) -> void:
	fov = clamp(new_fov, min_fov, max_fov)


## Gets the current desired distance
func get_desired_distance() -> float:
	return _desired_distance


## Gets the current actual distance (may differ due to obstruction)
func get_current_distance() -> float:
	return _current_distance


## Enables or disables mouse capture
func set_mouse_captured(captured: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE
