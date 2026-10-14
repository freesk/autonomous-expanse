extends Control
## Pause menu controller

@onready var resume_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonsContainer/ResumeButton
@onready var settings_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonsContainer/SettingsButton
@onready var main_menu_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonsContainer/MainMenuButton
@onready var quit_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonsContainer/QuitButton

@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var settings_close_button: Button = $SettingsPanel/MarginContainer/VBoxContainer/CloseButton

@onready var master_volume_slider: HSlider = $SettingsPanel/MarginContainer/VBoxContainer/TabContainer/Audio/MasterVolumeSlider
@onready var music_volume_slider: HSlider = $SettingsPanel/MarginContainer/VBoxContainer/TabContainer/Audio/MusicVolumeSlider
@onready var sfx_volume_slider: HSlider = $SettingsPanel/MarginContainer/VBoxContainer/TabContainer/Audio/SFXVolumeSlider
@onready var fullscreen_check: CheckButton = $SettingsPanel/MarginContainer/VBoxContainer/TabContainer/Graphics/FullscreenCheck
@onready var vsync_check: CheckButton = $SettingsPanel/MarginContainer/VBoxContainer/TabContainer/Graphics/VSyncCheck

signal resume_requested
signal main_menu_requested


func _ready() -> void:
	# Connect button signals
	resume_button.pressed.connect(_on_resume_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	settings_close_button.pressed.connect(_on_settings_close_pressed)

	# Connect settings controls
	master_volume_slider.value_changed.connect(_on_master_volume_changed)
	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	vsync_check.toggled.connect(_on_vsync_toggled)

	# Load settings
	_load_settings()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		if settings_panel.visible:
			settings_panel.visible = false
		else:
			_on_resume_pressed()
		get_viewport().set_input_as_handled()


func show_menu() -> void:
	## Show the pause menu
	visible = true
	get_tree().paused = true
	resume_button.grab_focus()


func hide_menu() -> void:
	## Hide the pause menu
	visible = false
	settings_panel.visible = false
	get_tree().paused = false


func _load_settings() -> void:
	## Load settings from SettingsManager
	if not Engine.has_singleton("SettingsManager"):
		return

	# TODO: Load settings from SettingsManager autoload
	pass


func _on_resume_pressed() -> void:
	## Resume the game
	hide_menu()
	resume_requested.emit()


func _on_settings_pressed() -> void:
	## Open settings panel
	settings_panel.visible = true


func _on_settings_close_pressed() -> void:
	## Close settings panel
	settings_panel.visible = false


func _on_main_menu_pressed() -> void:
	## Return to main menu
	hide_menu()
	main_menu_requested.emit()

	# Change scene
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _on_quit_pressed() -> void:
	## Quit the game
	get_tree().quit()


func _on_master_volume_changed(value: float) -> void:
	## Handle master volume change
	var volume_db := linear_to_db(value / 100.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), volume_db)


func _on_music_volume_changed(value: float) -> void:
	## Handle music volume change
	var volume_db := linear_to_db(value / 100.0)
	var music_bus := AudioServer.get_bus_index("Music")
	if music_bus != -1:
		AudioServer.set_bus_volume_db(music_bus, volume_db)


func _on_sfx_volume_changed(value: float) -> void:
	## Handle SFX volume change
	var volume_db := linear_to_db(value / 100.0)
	var sfx_bus := AudioServer.get_bus_index("SFX")
	if sfx_bus != -1:
		AudioServer.set_bus_volume_db(sfx_bus, volume_db)


func _on_fullscreen_toggled(enabled: bool) -> void:
	## Handle fullscreen toggle
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _on_vsync_toggled(enabled: bool) -> void:
	## Handle VSync toggle
	if enabled:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
