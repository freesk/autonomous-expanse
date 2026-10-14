extends Camera3D
class_name FreeCamera

## Free-roaming camera controller for sandbox world
## Controls: WASD movement, Mouse look, Shift sprint, ESC release mouse, Scroll for speed

## Movement speeds
@export var base_speed: float = 50.0
@export var sprint_speed: float = 400.0
@export var scroll_speed_increment: float = 10.0
@export var min_speed: float = 10.0
@export var max_speed: float = 500.0

## Mouse sensitivity
@export var mouse_sensitivity: float = 0.002

## Vertical look limits (degrees)
@export var pitch_min: float = -89.0
@export var pitch_max: float = 89.0

## Internal state
var current_speed: float
var mouse_captured: bool = false
var rotation_x: float = 0.0
var rotation_y: float = 0.0


func _ready() -> void:
	current_speed = base_speed

	# Set initial rotation from camera's current rotation
	rotation_x = rotation.x
	rotation_y = rotation.y

	# Capture mouse on start
	_capture_mouse()

	print("[FreeCamera] Ready - Click to capture mouse, ESC to release")
	print("  Controls: WASD/QE = Move, Mouse = Look, Shift = Sprint, Scroll = Speed")


func _input(event: InputEvent) -> void:
	# Toggle mouse capture with ESC
	if event.is_action_pressed("ui_cancel"):
		if mouse_captured:
			_release_mouse()
		get_viewport().set_input_as_handled()
		return

	# Capture mouse on click when not captured
	if event is InputEventMouseButton:
		if not mouse_captured and event.pressed:
			_capture_mouse()
			get_viewport().set_input_as_handled()
			return

	# Handle mouse movement when captured
	if mouse_captured and event is InputEventMouseMotion:
		_handle_mouse_motion(event.relative)
		get_viewport().set_input_as_handled()

	# Handle scroll wheel for speed adjustment
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			current_speed = min(current_speed + scroll_speed_increment, max_speed)
			print("[FreeCamera] Speed: %.1f" % current_speed)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			current_speed = max(current_speed - scroll_speed_increment, min_speed)
			print("[FreeCamera] Speed: %.1f" % current_speed)
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not mouse_captured:
		return

	_handle_movement(delta)


func _handle_mouse_motion(relative: Vector2) -> void:
	# Adjust yaw (Y rotation)
	rotation_y -= relative.x * mouse_sensitivity

	# Adjust pitch (X rotation) with limits
	rotation_x -= relative.y * mouse_sensitivity
	rotation_x = clamp(rotation_x, deg_to_rad(pitch_min), deg_to_rad(pitch_max))

	# Apply rotation
	rotation.x = rotation_x
	rotation.y = rotation_y


func _handle_movement(delta: float) -> void:
	var input_dir := Vector3.ZERO

	# Get input direction (local space)
	if Input.is_action_pressed("move_forward"):
		input_dir.z -= 1.0
	if Input.is_action_pressed("move_back"):
		input_dir.z += 1.0
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1.0

	# Up/Down movement (Q/E keys if available, or Space/Ctrl)
	if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_SPACE):
		input_dir.y += 1.0
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_CTRL):
		input_dir.y -= 1.0

	# Normalize input to prevent faster diagonal movement
	if input_dir.length() > 0:
		input_dir = input_dir.normalized()

	# Determine current speed (boost/sprint or normal)
	var speed := current_speed
	if Input.is_action_pressed("boost"):
		speed = sprint_speed

	# Transform direction from local to global space
	var velocity := transform.basis * input_dir * speed * delta

	# Apply movement
	global_position += velocity


func _capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	mouse_captured = true
	print("[FreeCamera] Mouse captured - Press ESC to release")


func _release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mouse_captured = false
	print("[FreeCamera] Mouse released - Click to recapture")


## Set camera position and look at target
func set_position_and_target(pos: Vector3, target: Vector3) -> void:
	global_position = pos
	look_at(target, Vector3.UP)
	rotation_x = rotation.x
	rotation_y = rotation.y


## Set camera speed
func set_speed(speed: float) -> void:
	current_speed = clamp(speed, min_speed, max_speed)
