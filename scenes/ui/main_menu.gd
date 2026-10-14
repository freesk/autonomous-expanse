extends Control
## Main menu controller

@onready var new_game_button: Button = $CenterContainer/VBoxContainer/MenuButtons/NewGameButton
@onready var continue_button: Button = $CenterContainer/VBoxContainer/MenuButtons/ContinueButton
@onready var settings_button: Button = $CenterContainer/VBoxContainer/MenuButtons/SettingsButton
@onready var credits_button: Button = $CenterContainer/VBoxContainer/MenuButtons/CreditsButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/MenuButtons/QuitButton

@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var credits_panel: PanelContainer = $CreditsPanel

@onready var master_volume_slider: HSlider = $SettingsPanel/MarginContainer/VBoxContainer/AudioSection/MasterVolumeSlider
@onready var music_volume_slider: HSlider = $SettingsPanel/MarginContainer/VBoxContainer/AudioSection/MusicVolumeSlider
@onready var sfx_volume_slider: HSlider = $SettingsPanel/MarginContainer/VBoxContainer/AudioSection/SFXVolumeSlider
@onready var fullscreen_check: CheckButton = $SettingsPanel/MarginContainer/VBoxContainer/GraphicsSection/FullscreenCheck
@onready var vsync_check: CheckButton = $SettingsPanel/MarginContainer/VBoxContainer/GraphicsSection/VSyncCheck

@onready var settings_close_button: Button = $SettingsPanel/MarginContainer/VBoxContainer/CloseButton
@onready var credits_close_button: Button = $CreditsPanel/MarginContainer/VBoxContainer/CloseButton


func _ready() -> void:
	# Connect button signals
	new_game_button.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	credits_button.pressed.connect(_on_credits_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	settings_close_button.pressed.connect(_on_settings_close_pressed)
	credits_close_button.pressed.connect(_on_credits_close_pressed)

	# Connect settings controls
	master_volume_slider.value_changed.connect(_on_master_volume_changed)
	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	vsync_check.toggled.connect(_on_vsync_toggled)

	# Check for existing save game
	_check_save_exists()

	# Load settings
	_load_settings()


func _check_save_exists() -> void:
	## Check if a save file exists to enable continue button
	# TODO: Implement save system check
	var save_exists := FileAccess.file_exists("user://save_game.dat")
	continue_button.disabled = not save_exists


func _load_settings() -> void:
	## Load settings from SettingsManager
	if not Engine.has_singleton("SettingsManager"):
		return

	# TODO: Load settings from SettingsManager autoload
	# master_volume_slider.value = SettingsManager.get_master_volume()
	# music_volume_slider.value = SettingsManager.get_music_volume()
	# sfx_volume_slider.value = SettingsManager.get_sfx_volume()
	# fullscreen_check.button_pressed = SettingsManager.is_fullscreen()
	# vsync_check.button_pressed = SettingsManager.is_vsync_enabled()


func _on_new_game_pressed() -> void:
	## Start a new game
	print("Starting new game...")

	# Load game world
	if Engine.has_singleton("GameManager"):
		# GameManager.start_new_game()
		pass

	get_tree().change_scene_to_file("res://scenes/game_world.tscn")


func _on_continue_pressed() -> void:
	## Continue from last save
	print("Continuing game...")

	# Load game world
	if Engine.has_singleton("GameManager"):
		# GameManager.load_game()
		pass

	get_tree().change_scene_to_file("res://scenes/game_world.tscn")


func _on_settings_pressed() -> void:
	## Open settings panel
	settings_panel.visible = true


func _on_settings_close_pressed() -> void:
	## Close settings panel
	settings_panel.visible = false


func _on_credits_pressed() -> void:
	## Open credits panel
	credits_panel.visible = true


func _on_credits_close_pressed() -> void:
	## Close credits panel
	credits_panel.visible = false


func _on_quit_pressed() -> void:
	## Quit the game
	print("Quitting game...")
	get_tree().quit()


func _on_master_volume_changed(value: float) -> void:
	## Handle master volume change
	var volume_db := linear_to_db(value / 100.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), volume_db)

	# Save to settings
	if Engine.has_singleton("SettingsManager"):
		# SettingsManager.set_master_volume(value)
		pass


func _on_music_volume_changed(value: float) -> void:
	## Handle music volume change
	var volume_db := linear_to_db(value / 100.0)
	var music_bus := AudioServer.get_bus_index("Music")
	if music_bus != -1:
		AudioServer.set_bus_volume_db(music_bus, volume_db)

	# Save to settings
	if Engine.has_singleton("SettingsManager"):
		# SettingsManager.set_music_volume(value)
		pass


func _on_sfx_volume_changed(value: float) -> void:
	## Handle SFX volume change
	var volume_db := linear_to_db(value / 100.0)
	var sfx_bus := AudioServer.get_bus_index("SFX")
	if sfx_bus != -1:
		AudioServer.set_bus_volume_db(sfx_bus, volume_db)

	# Save to settings
	if Engine.has_singleton("SettingsManager"):
		# SettingsManager.set_sfx_volume(value)
		pass


func _on_fullscreen_toggled(enabled: bool) -> void:
	## Handle fullscreen toggle
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	# Save to settings
	if Engine.has_singleton("SettingsManager"):
		# SettingsManager.set_fullscreen(enabled)
		pass


func _on_vsync_toggled(enabled: bool) -> void:
	## Handle VSync toggle
	if enabled:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	# Save to settings
	if Engine.has_singleton("SettingsManager"):
		# SettingsManager.set_vsync(enabled)
		pass
