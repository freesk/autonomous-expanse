class_name MoveCommand extends AICommand
## Command to move drone in a direction with climb rate

var direction: Vector2  ## XZ movement direction (normalized)
var climb: float  ## Y movement (-1 to 1)
var speed_fraction: float = 1.0  ## Speed multiplier (0 to 1)

func _init(dir: Vector2, climb_rate: float, speed: float = 1.0):
	command_type = CommandType.MOVE
	direction = dir
	climb = climb_rate
	speed_fraction = speed
	timestamp = Time.get_ticks_msec() / 1000.0

func execute(context: AICommandContext) -> void:
	if is_cancelled:
		return

	context.motion_system.set_movement(direction, climb, speed_fraction)
	is_completed = true

func to_dict() -> Dictionary:
	var d = super.to_dict()
	d["direction"] = [direction.x, direction.y]
	d["climb"] = climb
	d["speed"] = speed_fraction
	return d

static func from_dict(data: Dictionary) -> MoveCommand:
	var dir = Vector2(data["direction"][0], data["direction"][1])
	var cmd = MoveCommand.new(dir, data["climb"], data.get("speed", 1.0))
	cmd.priority = data.get("priority", 0)
	return cmd
