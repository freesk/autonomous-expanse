extends StaticBody3D
class_name ResourceNode

## Harvestable and destructible resource node
## Can be scanned and collected by cargo drones
## Can be destroyed by weapons

signal scanned(resource_data: Dictionary)
signal collected(resource_type: String, amount: int)
signal depleted()
signal destroyed()

enum ResourceType {
	IRON,
	COPPER,
}

@export var resource_type: ResourceType = ResourceType.IRON
@export var resource_amount: int = 500
@export var harvest_rate: float = 10.0 # Units per second
@export var respawn_enabled: bool = true
@export var respawn_time: float = 60.0 # 1 minute

@export_group("Health")
@export var max_health: float = 200.0 # Destructible by weapons

@export_group("Visual Settings")
@export var resource_color: Color = Color(0.6, 0.45, 0.3)
@export var emission_color: Color = Color(0.7, 0.5, 0.2)
@export var glow_intensity: float = 0.4

var _current_amount: int
var _current_health: float
var _is_depleted: bool = false
var _is_being_harvested: bool = false
var _respawn_timer: float = 0.0
var _interaction_area: Area3D
var _mesh: MeshInstance3D
var _label: Label3D


func _ready() -> void:
	_current_amount = resource_amount
	_current_health = max_health
	_setup_references()
	_setup_visuals()
	_setup_interaction()


func _process(delta: float) -> void:
	if _is_depleted and respawn_enabled:
		_respawn_timer += delta
		if _respawn_timer >= respawn_time:
			_respawn()


## Scan the resource node to get information
func scan() -> Dictionary:
	var data: Dictionary = {
		"type": _get_resource_name(),
		"amount": _current_amount,
		"max_amount": resource_amount,
		"percentage": float(_current_amount) / float(resource_amount) * 100.0,
		"position": global_position,
		"depleted": _is_depleted
	}

	scanned.emit(data)
	return data


## Start harvesting the resource
func start_harvest() -> bool:
	if _is_depleted or _is_being_harvested:
		return false

	_is_being_harvested = true
	return true


## Stop harvesting the resource
func stop_harvest() -> void:
	_is_being_harvested = false


## Harvest resources (called continuously while harvesting)
func harvest(delta: float) -> int:
	if _is_depleted or not _is_being_harvested:
		return 0

	var harvest_amount: int = int(harvest_rate * delta)
	harvest_amount = min(harvest_amount, _current_amount)

	_current_amount -= harvest_amount

	if _current_amount <= 0:
		_current_amount = 0
		_set_depleted()

	_update_label()
	return harvest_amount


## Instantly collect a specific amount
func collect(amount: int) -> int:
	if _is_depleted:
		return 0

	var collected_amount: int = min(amount, _current_amount)
	_current_amount -= collected_amount

	if _current_amount <= 0:
		_current_amount = 0
		_set_depleted()

	collected.emit(_get_resource_name(), collected_amount)
	_update_label()
	return collected_amount


## Check if the resource is depleted
func is_depleted() -> bool:
	return _is_depleted


## Get the resource type name
func get_resource_type_name() -> String:
	return _get_resource_name()


## Get remaining amount
func get_remaining_amount() -> int:
	return _current_amount


# Private methods

func _setup_references() -> void:
	# InteractionArea removed - detection handled by FactionManager.all_pois
	_interaction_area = null
	# Try to find mesh node - could be named "Mesh" or "Model"
	if has_node("Mesh"):
		_mesh = $Mesh as MeshInstance3D
	elif has_node("Model"):
		var model_node = $Model
		# Try to find the actual mesh instance inside the GLB model
		if model_node and model_node.get_child_count() > 0:
			for child in model_node.get_children():
				if child is MeshInstance3D:
					_mesh = child as MeshInstance3D
					break
	_label = $Label3D


func _setup_visuals() -> void:
	# Leave resource textures as-is - don't tint them
	# The original textures already look good
	_update_label()


func _setup_interaction() -> void:
	if _interaction_area:
		_interaction_area.body_entered.connect(_on_body_entered)
		_interaction_area.body_exited.connect(_on_body_exited)


func _update_label() -> void:
	if _label:
		if _is_depleted:
			_label.text = "Depleted"
			_label.modulate = Color(0.5, 0.5, 0.5)
		else:
			var health_percentage: float = (_current_health / max_health) * 100.0
			_label.text = "%s\nHP: %d%%" % [_get_resource_name(), int(health_percentage)]

			# Color based on health
			if health_percentage > 60:
				_label.modulate = Color.GREEN
			elif health_percentage > 30:
				_label.modulate = Color.YELLOW
			else:
				_label.modulate = Color.RED


func _set_depleted() -> void:
	_is_depleted = true
	_is_being_harvested = false
	_respawn_timer = 0.0

	# Visual feedback
	if _mesh:
		_mesh.visible = false

	var particles: GPUParticles3D = get_node_or_null("GlowParticles")
	if particles:
		particles.emitting = false

	_update_label()
	depleted.emit()


func _respawn() -> void:
	_current_amount = resource_amount
	_current_health = max_health
	_is_depleted = false
	_respawn_timer = 0.0

	# Visual feedback
	if _mesh:
		_mesh.visible = true

	var particles: GPUParticles3D = get_node_or_null("GlowParticles")
	if particles:
		particles.emitting = true

	_update_label()


## Take damage from weapons - makes resource destructible
func take_damage(amount: float, attacker: Node3D = null) -> void:
	if _is_depleted or amount <= 0:
		return

	_current_health -= amount

	# Update label to show health percentage
	_update_label()

	# Destroy resource if health depleted
	if _current_health <= 0:
		_current_health = 0
		_set_depleted()
		destroyed.emit()
		print("[ResourceNode:%s] Destroyed by %s" % [
			_get_resource_name(),
			attacker.name if attacker else "unknown"
		])


func _get_resource_name() -> String:
	match resource_type:
		ResourceType.IRON:
			return "Iron"
		ResourceType.COPPER:
			return "Copper"
		_:
			return "Unknown"


func _on_body_entered(body: Node3D) -> void:
	# Notify cargo drones or explorer drones
	if body.has_method("on_resource_detected"):
		body.on_resource_detected(self )


func _on_body_exited(body: Node3D) -> void:
	# Notify drones that resource is out of range
	if body.has_method("on_resource_lost"):
		body.on_resource_lost(self )
