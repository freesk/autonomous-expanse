extends CanvasLayer

## Loading Overlay UI
## Displays loading progress and status messages as an overlay on top of the main scene

@onready var control: Control = $Control
@onready var status_label: Label = $Control/CenterContainer/VBoxContainer/StatusLabel
@onready var progress_bar: ProgressBar = $Control/CenterContainer/VBoxContainer/ProgressBar
@onready var percentage_label: Label = $Control/CenterContainer/VBoxContainer/PercentageLabel


func _ready() -> void:
	# Make sure we're visible initially
	show()
	progress_bar.value = 0.0
	update_progress(0.0, "Initializing...")


## Update loading progress
func update_progress(progress: float, status: String = "") -> void:
	if not is_node_ready():
		await ready

	if progress_bar:
		progress_bar.value = clamp(progress, 0.0, 1.0)
	if percentage_label:
		percentage_label.text = "%d%%" % int(progress * 100.0)
	if status != "" and status_label:
		status_label.text = status


## Hide the loading overlay (called when loading complete)
func finish() -> void:
	# Fade out animation
	var tween = create_tween()
	tween.tween_property(control, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
