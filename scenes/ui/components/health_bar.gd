extends VBoxContainer
## Reusable health/shield bar component

@onready var label: Label = $Label
@onready var progress_bar: ProgressBar = $BarContainer/ProgressBar
@onready var value_label: Label = $BarContainer/ValueLabel

@export var bar_color: Color = Color(0, 1, 0):
	set(value):
		bar_color = value
		if progress_bar:
			progress_bar.modulate = bar_color

@export var low_health_threshold: float = 0.3
@export var low_health_color: Color = Color(1, 0, 0)
@export var mid_health_color: Color = Color(1, 1, 0)


func _ready() -> void:
	progress_bar.modulate = bar_color


func set_label_text(text: String) -> void:
	## Set the label text
	var lbl = get_node_or_null("Label")
	if lbl:
		lbl.text = text
	else:
		print("[HealthBar] ERROR: Label node not found when setting text to: ", text)


func set_values(current: float, maximum: float) -> void:
	## Update the bar values
	# Get nodes directly (don't rely on @onready with dynamic instantiation)
	var prog_bar = get_node_or_null("BarContainer/ProgressBar")
	var val_label = get_node_or_null("BarContainer/ValueLabel")

	if prog_bar == null:
		print("[HealthBar] ERROR: progress_bar not found!")
		return
	if val_label == null:
		print("[HealthBar] ERROR: value_label not found!")
		return

	prog_bar.max_value = maximum
	prog_bar.value = current
	val_label.text = "%d / %d" % [int(current), int(maximum)]

	# Update color based on percentage
	var percent := current / maximum
	if percent <= low_health_threshold:
		prog_bar.modulate = low_health_color
	elif percent <= 0.6:
		prog_bar.modulate = mid_health_color
	else:
		prog_bar.modulate = bar_color


func get_current_value() -> float:
	## Get current bar value
	return progress_bar.value


func get_max_value() -> float:
	## Get max bar value
	return progress_bar.max_value
