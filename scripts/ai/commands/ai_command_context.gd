class_name AICommandContext extends RefCounted
## Context passed to commands during execution
##
## Contains all the dependencies a command needs to execute.
## Commands don't hold references to these - they receive them during execution.

var drone: IDrone
var physics_query: IPhysicsQuery
var motion_system: IMotionSystem
var weapon_system: IWeaponSystem

func _init(
	drone_ref: IDrone,
	physics_ref: IPhysicsQuery,
	motion_ref: IMotionSystem,
	weapon_ref: IWeaponSystem
):
	drone = drone_ref
	physics_query = physics_ref
	motion_system = motion_ref
	weapon_system = weapon_ref
