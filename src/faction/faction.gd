class_name Faction
extends RefCounted

## Faction data structure for multi-faction AI simulation
## Manages faction identity, relations, and statistics tracking

## Unique faction identifier (0, 1, 2)
var faction_id: int = 0

## Display name of the faction
var faction_name: String = ""

## Faction color for visual identification
var faction_color: Color = Color.WHITE

## Relations with other factions: Dictionary[int, float]
## Key: faction_id, Value: relation score (-100.0 = hostile, 0.0 = neutral, 100.0 = allied)
var relations: Dictionary = {}

## Relation with player (-100.0 = hostile, 0.0 = neutral, 100.0 = allied)
## Starts at 0.0 (neutral) - only becomes hostile if player attacks this faction
var player_relation: float = 0.0

## All motherships owned by this faction
var motherships: Array = []

## All active squads belonging to this faction
var squads: Array = []

## Fleeing behavior: retreat when squad size drops below this ratio of starting size
@export var run_away_ratio: float = 0.5

## Fleeing behavior: retreat when outnumbered by this ratio vs enemies
@export var run_away_vs_enemy: float = 1.5

# Statistics tracking
var total_resources_collected: int = 0
var total_kills: int = 0
var total_losses: int = 0


## Constructor
func _init(id: int = 0, name: String = "", color: Color = Color.WHITE) -> void:
	faction_id = id
	faction_name = name
	faction_color = color


## Spawn a new squad for this faction at the given position
## Returns: DroneSquad instance
func spawn_squad(position: Vector3) -> Node:
	# This will be implemented when DroneSquad is created in Phase 5
	push_warning("[Faction] spawn_squad not yet implemented - Phase 5")
	return null


## Register a mothership to this faction
func register_mothership(mothership: Node) -> void:
	if not motherships.has(mothership):
		motherships.append(mothership)


## Unregister a mothership from this faction
func unregister_mothership(mothership: Node) -> void:
	motherships.erase(mothership)


## Register a squad to this faction
func register_squad(squad: Node) -> void:
	if not squads.has(squad):
		squads.append(squad)


## Unregister a squad from this faction
func unregister_squad(squad: Node) -> void:
	squads.erase(squad)


## Get relation value with another faction
## Returns: float (-100.0 to 100.0)
func get_relation(other_faction_id: int) -> float:
	if relations.has(other_faction_id):
		return relations[other_faction_id]
	return 0.0


## Set relation value with another faction
func set_relation(other_faction_id: int, value: float) -> void:
	relations[other_faction_id] = clampf(value, -100.0, 100.0)


## Check if this faction is hostile to another faction
func is_hostile_to(other_faction_id: int) -> bool:
	return get_relation(other_faction_id) < 0.0


## Check if this faction is hostile to the player
func is_hostile_to_player() -> bool:
	return player_relation < 0.0


## Set this faction to be hostile to the player (when player attacks)
func set_hostile_to_player() -> void:
	player_relation = -100.0
	print("[Faction:%s] Now hostile to player!" % faction_name)


## Get faction statistics as a formatted string
func get_stats_summary() -> String:
	return """[%s]
  Motherships: %d
  Active Squads: %d
  Resources Collected: %d
  Kills: %d | Losses: %d""" % [
		faction_name,
		motherships.size(),
		squads.size(),
		total_resources_collected,
		total_kills,
		total_losses
	]
