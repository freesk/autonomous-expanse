extends Node

## AIDebugLogger - Central log of AI decisions for drones and squads
##
## Every meaningful AI decision (state transition, combat behavior change,
## goal change, fire/stop-fire, target switch) is recorded with its REASON
## and the context data that drove it. This makes AI behavior auditable:
## for any drone you can ask "what did you decide and why".
##
## Usage from AI code:
##   AIDebugLogger.log_decision("drone:Fighter2", "CombatAI", "strafe", "in_optimal_range",
##       {"distance": 62.0, "health_pct": 80.0})
##   AIDebugLogger.log_status(...)  # throttled, for periodic status lines
##
## Inspection:
##   AIDebugLogger.get_entities()        -> all entities that logged decisions
##   AIDebugLogger.get_history(entity)   -> last N decisions for one entity
##   AIDebugLogger.dump_entity(entity)   -> formatted multi-line string
##   Full session log is also written to user://logs/ai_decisions_<ts>.log

signal decision_logged(entity: String, entry: Dictionary)

## Master switch - set false to silence all AI decision logging
var enabled: bool = true
## Echo every decision to the output console
var echo_to_console: bool = true
## Persist the full session to user://logs/
var write_to_file: bool = true
## Ring buffer size per entity
var max_history_per_entity: int = 200

var _history: Dictionary = {}  # entity (String) -> Array[Dictionary]
var _throttle: Dictionary = {}  # "entity/system/status" -> last log time (seconds)
var _file: FileAccess = null


func _ready() -> void:
	if write_to_file:
		_open_log_file()


func _open_log_file() -> void:
	var err := DirAccess.make_dir_recursive_absolute("user://logs")
	if err != OK and err != ERR_ALREADY_EXISTS:
		push_warning("[AIDebugLogger] Could not create user://logs (err %d)" % err)
		return

	var ts := Time.get_datetime_string_from_system().replace(":", "-")
	var path := "user://logs/ai_decisions_%s.log" % ts
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file:
		print("[AIDebugLogger] AI decision log: %s" % ProjectSettings.globalize_path(path))
	else:
		push_warning("[AIDebugLogger] Could not open %s for writing" % path)


## Record a discrete decision. Call this when the AI *changes* something
## (state, behavior, goal, target, fire state) - not every frame.
func log_decision(entity: String, system: String, decision: String, reason: String, data: Dictionary = {}) -> void:
	if not enabled:
		return

	var entry := {
		"time": Time.get_ticks_msec() / 1000.0,
		"system": system,
		"decision": decision,
		"reason": reason,
		"data": data,
	}

	if not _history.has(entity):
		_history[entity] = []
	var entries: Array = _history[entity]
	entries.append(entry)
	if entries.size() > max_history_per_entity:
		entries.pop_front()

	var line := _format_line(entity, entry)
	if echo_to_console:
		print(line)
	if _file:
		_file.store_line(line)
		_file.flush()

	decision_logged.emit(entity, entry)


## Record periodic status (e.g. pursuit progress, energy level). Throttled:
## logs at most once per `interval` seconds per entity+system+status key.
func log_status(entity: String, system: String, status: String, data: Dictionary = {}, interval: float = 2.0) -> void:
	if not enabled:
		return

	var key := "%s/%s/%s" % [entity, system, status]
	var now := Time.get_ticks_msec() / 1000.0
	if _throttle.has(key) and now - _throttle[key] < interval:
		return
	_throttle[key] = now

	log_decision(entity, system, status, "status", data)


## All entities that have logged at least one decision
func get_entities() -> Array:
	return _history.keys()


## Last decisions for one entity (oldest first)
func get_history(entity: String) -> Array:
	return _history.get(entity, []).duplicate()


## Human-readable dump of one entity's decision history
func dump_entity(entity: String) -> String:
	var lines: PackedStringArray = []
	for entry in _history.get(entity, []):
		lines.append(_format_line(entity, entry))
	return "\n".join(lines)


## Human-readable dump of every entity's history
func dump_all() -> String:
	var sections: PackedStringArray = []
	for entity in _history.keys():
		sections.append("=== %s ===\n%s" % [entity, dump_entity(entity)])
	return "\n\n".join(sections)


## Convenience: stable entity name for a drone node
static func drone_entity(drone: Node) -> String:
	if drone and is_instance_valid(drone):
		return "drone:%s" % drone.name
	return "drone:?"


## Convenience: stable entity name for a squad
static func squad_entity(squad_id: int) -> String:
	return "squad:%d" % squad_id


func _format_line(entity: String, entry: Dictionary) -> String:
	var line := "[%8.2f] [%s] [%s] %s (reason: %s)" % [
		entry.time, entity, entry.system, entry.decision, entry.reason
	]
	var data: Dictionary = entry.data
	if not data.is_empty():
		var parts: PackedStringArray = []
		for key in data.keys():
			parts.append("%s=%s" % [key, _format_value(data[key])])
		line += " | " + ", ".join(parts)
	return line


func _format_value(value: Variant) -> String:
	if value is Object:
		if not is_instance_valid(value):
			return "<freed>"
		if value is Node:
			return value.name
		return str(value)
	if value is float:
		return "%.2f" % value
	return str(value)
