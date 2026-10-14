extends Node
class_name WeaponController

## WeaponController - Manages weapons and firing logic
## Finds weapons in hardpoint slots and handles firing

const WEAPON_BASE_SCRIPT = preload("res://src/weapons/weapon_base.gd")

## Weapon references
var primary_weapon: Node = null
var secondary_weapon: Node = null

## Parent drone
var drone: Node3D = null

## Aim target (set externally by AimSystem or AI)
var aim_target_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	drone = get_parent()
	if not drone:
		push_error("[WeaponController] Parent node required")
		return

	call_deferred("_cache_weapons")


func _cache_weapons() -> void:
	## Find weapons in hardpoint slots
	primary_weapon = _find_weapon_in_slot("WeaponHardpoints/PrimarySlot")
	secondary_weapon = _find_weapon_in_slot("WeaponHardpoints/SecondarySlot")

	if primary_weapon:
		print("[WeaponController] Found primary weapon: ", primary_weapon.name)
	if secondary_weapon:
		print("[WeaponController] Found secondary weapon: ", secondary_weapon.name)


func _find_weapon_in_slot(slot_path: String) -> Node:
	## Find weapon node in specified slot
	var slot := drone.get_node_or_null(slot_path)
	if not slot:
		return null

	var weapon := _find_weapon_recursive(slot)
	if weapon:
		# Set owner_drone property if available
		var has_owner_property := false
		for property_data in weapon.get_property_list():
			if property_data.get("name", "") == "owner_drone":
				has_owner_property = true
				break
		if has_owner_property:
			weapon.set("owner_drone", drone)

	return weapon


func _find_weapon_recursive(node: Node) -> Node:
	## Recursively search for weapon nodes
	for child in node.get_children():
		if _is_weapon_node(child):
			return child
		var nested := _find_weapon_recursive(child)
		if nested:
			return nested
	return null


func _is_weapon_node(node: Node) -> bool:
	## Check if node is a weapon
	var script_ref: Script = node.get_script() as Script
	while script_ref != null:
		if script_ref == WEAPON_BASE_SCRIPT:
			return true
		script_ref = script_ref.get_base_script()

	return node.has_method("try_fire") and node.has_method("set_aim_target")


func set_aim_target(target_pos: Vector3) -> void:
	## Set aim target for all weapons
	aim_target_position = target_pos

	if primary_weapon and primary_weapon.has_method("set_aim_target"):
		primary_weapon.call("set_aim_target", target_pos)
	if secondary_weapon and secondary_weapon.has_method("set_aim_target"):
		secondary_weapon.call("set_aim_target", target_pos)


func try_fire_primary() -> bool:
	## Try to fire primary weapon
	if primary_weapon and primary_weapon.has_method("try_fire"):
		return bool(primary_weapon.call("try_fire"))
	return false


func try_fire_secondary() -> bool:
	## Try to fire secondary weapon
	if secondary_weapon and secondary_weapon.has_method("try_fire"):
		return bool(secondary_weapon.call("try_fire"))
	return false


func handle_weapon_input(wants_fire_primary: bool, wants_fire_secondary: bool) -> bool:
	## Handle weapon firing based on input
	var fired := false

	if wants_fire_primary:
		if try_fire_primary():
			fired = true

	if wants_fire_secondary:
		if try_fire_secondary():
			fired = true

	return fired
