extends Node
class_name MotionController

## MotionController - Handles player and AI motion input for drones
## Provides a unified interface for movement, rotation, and action inputs

signal fire_primary_requested()
signal fire_secondary_requested()
signal boost_requested(enabled: bool)

enum ControlMode {
	PLAYER,  ## Reads from Input system
	AI       ## Reads from AI variables
}

@export var control_mode: ControlMode = ControlMode.PLAYER

## AI Input Variables (set by external AI)
var ai_move_input: Vector2 = Vector2.ZERO  ## X = strafe, Y = forward/back
var ai_climb_input: float = 0.0  ## Vertical movement
var ai_fire_primary: bool = false
var ai_fire_secondary: bool = false
var ai_boost: bool = false
var ai_jump: bool = false  ## AI wants to jump
var ai_look_target: Vector3 = Vector3.ZERO  ## World position to look at (for rotation)

## Output - Current frame input state
var movement_input: Vector2 = Vector2.ZERO  ## X = strafe, Y = forward/back
var climb_input: float = 0.0
var wants_jump: bool = false  ## Tap Space for jump
var wants_boost: bool = false
var wants_fire_primary: bool = false
var wants_fire_secondary: bool = false


func _physics_process(_delta: float) -> void:
	if control_mode == ControlMode.PLAYER:
		_read_player_input()
	else:
		_read_ai_input()


func _read_player_input() -> void:
	## Read input from Input system
	# Movement (inverted to match Godot conventions)
	movement_input.y = -Input.get_axis("move_forward", "move_back")
	movement_input.x = -Input.get_axis("move_right", "move_left")
	climb_input = Input.get_axis("move_down", "move_up")

	# Jump (tap space)
	wants_jump = Input.is_action_just_pressed("move_up")

	# Actions
	wants_boost = Input.is_action_pressed("boost") and not Input.is_action_pressed("move_down")
	wants_fire_primary = Input.is_action_pressed("fire")
	wants_fire_secondary = Input.is_action_pressed("secondary_fire")


func _read_ai_input() -> void:
	## Read input from AI variables
	movement_input = ai_move_input
	climb_input = ai_climb_input
	wants_boost = ai_boost
	wants_jump = ai_jump
	wants_fire_primary = ai_fire_primary
	wants_fire_secondary = ai_fire_secondary


## AI Control Interface

func set_ai_movement(move: Vector2, climb: float = 0.0) -> void:
	"""Set AI movement input"""
	ai_move_input = move
	ai_climb_input = climb


func set_ai_fire(primary: bool, secondary: bool = false) -> void:
	"""Set AI weapon firing"""
	ai_fire_primary = primary
	ai_fire_secondary = secondary


func set_ai_boost(enabled: bool) -> void:
	"""Set AI boost"""
	ai_boost = enabled


func set_ai_jump(enabled: bool) -> void:
	"""Set AI jump - triggers jump impulse"""
	ai_jump = enabled


func set_ai_look_target(target_pos: Vector3) -> void:
	"""Set AI look target (world position to face)"""
	ai_look_target = target_pos


## Utility

func is_player_controlled() -> bool:
	"""Check if this drone is controlled by the player"""
	return control_mode == ControlMode.PLAYER


func get_movement_direction() -> Vector3:
	"""Get movement direction in local space"""
	return Vector3(movement_input.x, climb_input, movement_input.y)


func has_movement_input() -> bool:
	"""Check if there's any movement input"""
	return movement_input.length_squared() > 0.01 or abs(climb_input) > 0.01
