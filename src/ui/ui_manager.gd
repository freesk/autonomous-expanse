extends Node

## UIManager - UI state and screen management
##
## Manages UI screens, HUD elements, menus, and UI transitions.
## Autoloaded as a singleton for global access.

signal screen_changed(old_screen: String, new_screen: String)
signal hud_visibility_changed(visible: bool)
signal notification_displayed(message: String, type: NotificationType)
signal pause_toggled(paused: bool)
signal input_mode_changed(mode: InputMode)

enum NotificationType {
	INFO,
	SUCCESS,
	WARNING,
	ERROR
}

enum InputMode {
	KEYBOARD_MOUSE,
	GAMEPAD
}

# Preloaded scenes
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const PAUSE_MENU_SCENE := preload("res://scenes/ui/pause_menu.tscn")
const MOTHERSHIP_UI_SCENE := preload("res://scenes/ui/mothership_ui.tscn")

var current_screen: String = "none"
var hud_visible: bool = true
var active_screens: Dictionary = {}  # screen_name -> Control node

# References to UI elements
var hud_node: CanvasLayer = null
var pause_menu_node: Control = null
var settings_menu_node: Control = null
var mothership_ui_node: Control = null

# State
var is_paused: bool = false
var is_in_mothership: bool = false
var input_mode: InputMode = InputMode.KEYBOARD_MOUSE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("UIManager initialized")


func _input(event: InputEvent) -> void:
	# Handle pause input
	if event.is_action_pressed("ui_cancel") and not is_in_mothership:
		toggle_pause()

	# Detect input mode changes
	_detect_input_mode(event)


func _detect_input_mode(event: InputEvent) -> void:
	## Detect and switch input mode
	var new_mode := input_mode

	if event is InputEventKey or event is InputEventMouse:
		new_mode = InputMode.KEYBOARD_MOUSE
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		new_mode = InputMode.GAMEPAD

	if new_mode != input_mode:
		input_mode = new_mode
		input_mode_changed.emit(input_mode)


func register_screen(screen_name: String, screen_node) -> void:
	active_screens[screen_name] = screen_node
	print("UI screen registered: ", screen_name)


func unregister_screen(screen_name: String) -> void:
	active_screens.erase(screen_name)


func show_screen(screen_name: String, hide_others: bool = true) -> void:
	if not active_screens.has(screen_name):
		push_warning("Screen not found: " + screen_name)
		return

	var old_screen = current_screen
	current_screen = screen_name

	if hide_others:
		for name in active_screens.keys():
			if name != screen_name:
				active_screens[name].hide()

	active_screens[screen_name].show()
	screen_changed.emit(old_screen, screen_name)


func hide_screen(screen_name: String) -> void:
	if active_screens.has(screen_name):
		active_screens[screen_name].hide()


func toggle_screen(screen_name: String) -> void:
	if not active_screens.has(screen_name):
		return

	var screen = active_screens[screen_name]
	if screen.visible:
		hide_screen(screen_name)
	else:
		show_screen(screen_name, false)


func set_hud_visible(visible: bool) -> void:
	hud_visible = visible
	if hud_node:
		hud_node.visible = visible
	hud_visibility_changed.emit(visible)


func toggle_hud() -> void:
	set_hud_visible(not hud_visible)


func initialize_game_ui() -> void:
	## Initialize HUD and menus for gameplay
	# Create HUD
	if hud_node == null:
		hud_node = HUD_SCENE.instantiate()
		get_tree().root.call_deferred("add_child", hud_node)
		register_screen("hud", hud_node)

	# Create pause menu
	if pause_menu_node == null:
		pause_menu_node = PAUSE_MENU_SCENE.instantiate()
		get_tree().root.call_deferred("add_child", pause_menu_node)
		pause_menu_node.visible = false
		register_screen("pause_menu", pause_menu_node)

		# Connect signals
		if pause_menu_node.has_signal("resume_requested"):
			pause_menu_node.resume_requested.connect(_on_resume_requested)
		if pause_menu_node.has_signal("main_menu_requested"):
			pause_menu_node.main_menu_requested.connect(_on_main_menu_requested)

	# Create mothership UI
	if mothership_ui_node == null:
		mothership_ui_node = MOTHERSHIP_UI_SCENE.instantiate()
		get_tree().root.call_deferred("add_child", mothership_ui_node)
		mothership_ui_node.visible = false
		register_screen("mothership", mothership_ui_node)

		# Connect signals
		if mothership_ui_node.has_signal("mothership_exited"):
			mothership_ui_node.mothership_exited.connect(_on_mothership_exited)


func cleanup_game_ui() -> void:
	## Clean up game UI when returning to main menu
	if hud_node != null:
		unregister_screen("hud")
		hud_node.queue_free()
		hud_node = null

	if pause_menu_node != null:
		unregister_screen("pause_menu")
		pause_menu_node.queue_free()
		pause_menu_node = null

	if mothership_ui_node != null:
		unregister_screen("mothership")
		mothership_ui_node.queue_free()
		mothership_ui_node = null


func toggle_pause() -> void:
	## Toggle pause state
	if is_in_mothership:
		return  # Don't allow pause while in mothership UI

	is_paused = not is_paused

	if is_paused:
		show_pause_menu()
	else:
		hide_pause_menu()

	pause_toggled.emit(is_paused)


func show_pause_menu() -> void:
	## Show the pause menu
	if pause_menu_node != null and pause_menu_node.has_method("show_menu"):
		pause_menu_node.show_menu()
		is_paused = true
		set_hud_visible(false)


func hide_pause_menu() -> void:
	## Hide the pause menu
	if pause_menu_node != null and pause_menu_node.has_method("hide_menu"):
		pause_menu_node.hide_menu()
		is_paused = false
		set_hud_visible(true)


func show_mothership_ui() -> void:
	## Show the mothership UI
	if mothership_ui_node != null and mothership_ui_node.has_method("show_mothership_ui"):
		mothership_ui_node.show_mothership_ui()
		is_in_mothership = true
		set_hud_visible(false)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func hide_mothership_ui() -> void:
	## Hide the mothership UI
	if mothership_ui_node != null and mothership_ui_node.has_method("hide_mothership_ui"):
		mothership_ui_node.hide_mothership_ui()
		is_in_mothership = false
		set_hud_visible(true)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func toggle_pause_menu() -> void:
	toggle_pause()


func show_notification(message: String, type: NotificationType = NotificationType.INFO, duration: float = 3.0) -> void:
	notification_displayed.emit(message, type)
	print("[NOTIFICATION] ", NotificationType.keys()[type], ": ", message)

	# Show on HUD if available
	if hud_node != null and hud_node.has_method("add_notification"):
		hud_node.add_notification(message, duration)


func update_health_bar(current: float, maximum: float) -> void:
	if hud_node and hud_node.has_method("_on_health_changed"):
		hud_node._on_health_changed(current, maximum)


func update_shields_bar(current: float, maximum: float) -> void:
	if hud_node and hud_node.has_method("_on_shield_changed"):
		hud_node._on_shield_changed(current, maximum)


func update_energy_bar(current: float, maximum: float) -> void:
	if hud_node and hud_node.has_method("_on_energy_changed"):
		hud_node._on_energy_changed(current, maximum)


func update_ammo_display(current: int, maximum: int) -> void:
	if hud_node and hud_node.has_method("update_ammo"):
		hud_node.update_ammo(current, maximum)


func update_velocity_display(velocity: Vector3) -> void:
	if hud_node and hud_node.has_method("update_velocity"):
		hud_node.update_velocity(velocity)


func update_altitude_display(altitude: float) -> void:
	if hud_node and hud_node.has_method("update_altitude"):
		hud_node.update_altitude(altitude)


func show_damage_indicator(direction: Vector3) -> void:
	if hud_node and hud_node.has_method("show_damage_indicator"):
		hud_node.show_damage_indicator(direction)


func show_objective(objective_text: String) -> void:
	if hud_node and hud_node.has_method("show_objective"):
		hud_node.show_objective(objective_text)


func set_drone(drone: RigidBody3D) -> void:
	## Set the current drone for the HUD
	if hud_node != null and hud_node.has_method("set_drone"):
		hud_node.set_drone(drone)


func show_enemy_lock_alert() -> void:
	## Show enemy lock-on alert
	if hud_node != null and hud_node.has_method("show_enemy_lock_alert"):
		hud_node.show_enemy_lock_alert()


func hide_enemy_lock_alert() -> void:
	## Hide enemy lock-on alert
	if hud_node != null and hud_node.has_method("hide_enemy_lock_alert"):
		hud_node.hide_enemy_lock_alert()


func _on_resume_requested() -> void:
	## Handle resume request from pause menu
	hide_pause_menu()


func _on_main_menu_requested() -> void:
	## Handle main menu request from pause menu
	cleanup_game_ui()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _on_mothership_exited() -> void:
	## Handle mothership exit
	hide_mothership_ui()


func clear_all() -> void:
	for screen in active_screens.values():
		screen.hide()
	current_screen = "none"
