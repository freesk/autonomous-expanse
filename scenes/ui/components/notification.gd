extends PanelContainer
## Pop-up notification component
## Shows temporary messages that fade out

@onready var label: Label = $MarginContainer/Label
@onready var fade_timer: Timer = $FadeTimer
@onready var animation_timer: Timer = $AnimationTimer

var _fade_duration: float = 0.5
var _is_fading: bool = false


func _ready() -> void:
	modulate.a = 0
	fade_timer.timeout.connect(_start_fade_out)
	animation_timer.timeout.connect(_fade_step)


func show_message(message: String, duration: float = 3.0) -> void:
	## Show a notification message
	label.text = message
	modulate.a = 0

	# Fade in
	_fade_in()

	# Set timer for fade out
	fade_timer.wait_time = duration
	fade_timer.start()


func _fade_in() -> void:
	## Fade in animation
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)


func _start_fade_out() -> void:
	## Start fading out
	_is_fading = true
	animation_timer.start()


func _fade_step() -> void:
	## Gradual fade out
	if not _is_fading:
		return

	modulate.a -= 0.05

	if modulate.a <= 0:
		animation_timer.stop()
		queue_free()
