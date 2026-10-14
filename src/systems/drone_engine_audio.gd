extends Node
class_name DroneEngineAudio

## DroneEngineAudio - Looping engine hum driven by actual thrust state
##
## Attach as a child of a drone (RigidBody3D). Creates an AudioStreamPlayer3D
## on the drone body and continuously maps ThrusterController.current_intensity
## (the same smoothed value that drives the thruster visuals) to the hum's
## pitch and volume, so the sound always matches what the drone is doing:
## idle hover = quiet low hum, full thrust/boost = louder and higher pitched.
##
## Each drone picks its engine sample variant deterministically from its name,
## and starts the loop at a name-derived offset so a squad of drones doesn't
## phase into one synchronized drone chorus.

const ENGINE_STREAM_PATHS: Array[String] = [
	"res://assets/audio/engines/spaceEngineLow_000.ogg",
	"res://assets/audio/engines/spaceEngineLow_001.ogg",
	"res://assets/audio/engines/spaceEngineLow_002.ogg",
	"res://assets/audio/engines/spaceEngineLow_003.ogg",
	"res://assets/audio/engines/spaceEngineLow_004.ogg",
]

@export_group("Volume")
## Hum volume at idle/hover thrust
@export var min_volume_db: float = -20.0
## Hum volume at maximum thrust
@export var max_volume_db: float = -8.0

@export_group("Pitch")
## Pitch at idle/hover thrust
@export var min_pitch: float = 0.85
## Pitch at maximum thrust
@export var max_pitch: float = 1.5

@export_group("Attenuation")
## Distance at which the hum becomes inaudible
@export var max_distance: float = 80.0
## Reference distance for attenuation falloff
@export var unit_size: float = 6.0

var drone: RigidBody3D = null
var thruster_controller: ThrusterController = null
var audio_player: AudioStreamPlayer3D = null


func _ready() -> void:
	drone = get_parent() as RigidBody3D
	if not drone:
		push_error("[DroneEngineAudio] Parent must be a RigidBody3D (drone)!")
		return

	thruster_controller = drone.get_node_or_null("ThrusterController")
	if not thruster_controller:
		push_warning("[DroneEngineAudio] ThrusterController not found, falling back to velocity-based hum")

	audio_player = AudioStreamPlayer3D.new()
	audio_player.name = "EngineHum"
	audio_player.bus = "SFX"
	audio_player.max_distance = max_distance
	audio_player.unit_size = unit_size
	audio_player.volume_db = min_volume_db
	audio_player.pitch_scale = min_pitch

	# Deterministic per-drone variant: the same drone always has the same voice
	var name_hash: int = abs(String(drone.name).hash())
	var variant: int = name_hash % ENGINE_STREAM_PATHS.size()
	audio_player.stream = load(ENGINE_STREAM_PATHS[variant])

	# AudioStreamPlayer3D must live under a Node3D to track the drone's position.
	# The drone may still be mid-setup, so defer the attach.
	drone.add_child.call_deferred(audio_player)
	_start_hum.call_deferred(name_hash)


func _start_hum(name_hash: int) -> void:
	if not is_instance_valid(audio_player) or not audio_player.stream:
		return
	audio_player.play()
	# Desynchronize loop phase between drones (deterministic, from the name hash)
	var length: float = audio_player.stream.get_length()
	if length > 0.0:
		audio_player.seek(fmod(float(name_hash) * 0.618, length))


func _process(_delta: float) -> void:
	if not drone or not audio_player or not audio_player.is_inside_tree():
		return

	# Safety net: keep the loop running even if the stream wasn't imported as looping
	if not audio_player.playing:
		audio_player.play()

	var throttle: float = _get_throttle()
	audio_player.pitch_scale = lerpf(min_pitch, max_pitch, throttle)
	audio_player.volume_db = lerpf(min_volume_db, max_volume_db, throttle)


## Normalized 0..1 thrust value from the thruster controller (shared with visuals),
## or from raw velocity if no controller is present.
func _get_throttle() -> float:
	if thruster_controller:
		var span: float = thruster_controller.max_intensity - thruster_controller.base_intensity
		if span > 0.0:
			return clampf(
				(thruster_controller.current_intensity - thruster_controller.base_intensity) / span,
				0.0, 1.0
			)
	return clampf(drone.linear_velocity.length() / 25.0, 0.0, 1.0)
