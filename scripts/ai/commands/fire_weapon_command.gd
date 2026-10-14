class_name FireWeaponCommand extends AICommand
## Command to fire weapons at a target position

var target_position: Vector3
var fire_primary: bool = true
var fire_secondary: bool = false
var min_energy_required: float = 20.0

func _init(target_pos: Vector3, primary: bool = true, secondary: bool = false):
	command_type = CommandType.FIRE_WEAPON
	target_position = target_pos
	fire_primary = primary
	fire_secondary = secondary
	timestamp = Time.get_ticks_msec() / 1000.0

func can_execute(context: AICommandContext) -> bool:
	if not super.can_execute(context):
		return false

	# Check energy requirements
	if context.drone.get_energy() < min_energy_required:
		return false

	return true

func execute(context: AICommandContext) -> void:
	if is_cancelled:
		return

	context.weapon_system.set_target(target_position)
	context.weapon_system.fire(fire_primary, fire_secondary)
	is_completed = true

func to_dict() -> Dictionary:
	var d = super.to_dict()
	d["target"] = [target_position.x, target_position.y, target_position.z]
	d["primary"] = fire_primary
	d["secondary"] = fire_secondary
	return d

static func from_dict(data: Dictionary) -> FireWeaponCommand:
	var target = Vector3(data["target"][0], data["target"][1], data["target"][2])
	var cmd = FireWeaponCommand.new(target, data.get("primary", true), data.get("secondary", false))
	cmd.priority = data.get("priority", 0)
	return cmd
