extends RefCounted
class_name FactionTerritory

## Handles faction territory division and position validation
## Map is divided into N pie slices based on number of factions


## Check if a position is within a specific faction's pie slice territory
## Territories are divided equally: 360 / n_factions degrees per slice
static func is_in_faction_territory(pos: Vector2, faction_id: int, n_factions: int = 3) -> bool:
	# Special case: single faction owns entire map
	if n_factions == 1:
		return faction_id == 0

	var angle := atan2(pos.y, pos.x)  # Returns angle in radians (-PI to PI)

	# Convert to degrees (0 to 360)
	var angle_degrees := rad_to_deg(angle)
	if angle_degrees < 0:
		angle_degrees += 360.0

	# Calculate pie slice size and ranges
	var slice_degrees := 360.0 / float(n_factions)
	var slice_start := faction_id * slice_degrees
	var slice_end := (faction_id + 1) * slice_degrees

	return angle_degrees >= slice_start and angle_degrees < slice_end


## Get the faction ID that controls a given position
static func get_faction_at_position(pos: Vector2, n_factions: int = 3) -> int:
	for faction_id in range(n_factions):
		if is_in_faction_territory(pos, faction_id, n_factions):
			return faction_id
	return -1  # Invalid
