extends Node

## LoadingManager - Singleton for managing game loading process
## Tracks loading progress and displays loading screen

signal loading_started()
signal loading_progress_updated(progress: float, status: String)
signal loading_completed()

const LOADING_OVERLAY_SCENE = preload("res://scenes/ui/loading_overlay.tscn")

var loading_overlay: CanvasLayer = null
var is_loading: bool = false

# Loading stages with weights (must sum to 1.0)
enum LoadingStage {
	RESOURCES,
	WORLD_GENERATION,
	PLAYER_SPAWN,
	CAMERA_SETUP,
	FACTIONS_INIT,
	COMPLETE
}

var stage_weights: Dictionary = {
	LoadingStage.RESOURCES: 0.2,
	LoadingStage.WORLD_GENERATION: 0.3,
	LoadingStage.PLAYER_SPAWN: 0.2,
	LoadingStage.CAMERA_SETUP: 0.1,
	LoadingStage.FACTIONS_INIT: 0.2,
}

var current_stage: LoadingStage = LoadingStage.RESOURCES
var stage_progress: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Continue processing during pause


## Start the loading process
func start_loading() -> void:
	if is_loading:
		return

	is_loading = true
	current_stage = LoadingStage.RESOURCES
	stage_progress = 0.0

	# Create and show loading overlay
	_show_loading_overlay()

	loading_started.emit()
	print("[LoadingManager] Loading started")


## Show the loading overlay
func _show_loading_overlay() -> void:
	if loading_overlay:
		return

	loading_overlay = LOADING_OVERLAY_SCENE.instantiate()
	get_tree().root.call_deferred("add_child", loading_overlay)
	# Wait for next frame to ensure loading overlay is ready
	await get_tree().process_frame
	if loading_overlay:
		loading_overlay.update_progress(0.0, "Starting...")


## Update progress for current stage
## stage_progress: 0.0 to 1.0 representing progress within current stage
func update_stage_progress(stage: LoadingStage, progress: float, status: String = "") -> void:
	if not is_loading:
		return

	current_stage = stage
	stage_progress = clamp(progress, 0.0, 1.0)

	# Calculate overall progress
	var overall_progress: float = _calculate_overall_progress()

	# Update loading overlay
	if loading_overlay:
		loading_overlay.update_progress(overall_progress, status)

	loading_progress_updated.emit(overall_progress, status)

	# Print progress for debugging
	print("[LoadingManager] Stage: %s | Progress: %.1f%% | Status: %s" % [
		LoadingStage.keys()[stage],
		overall_progress * 100.0,
		status
	])


## Calculate overall loading progress based on stage weights
func _calculate_overall_progress() -> float:
	var total_progress: float = 0.0

	# Add completed stages
	for stage in range(current_stage):
		if stage in stage_weights:
			total_progress += stage_weights[stage]

	# Add current stage progress
	if current_stage in stage_weights:
		total_progress += stage_weights[current_stage] * stage_progress

	return clamp(total_progress, 0.0, 1.0)


## Mark loading as complete
func finish_loading() -> void:
	if not is_loading:
		return

	update_stage_progress(LoadingStage.COMPLETE, 1.0, "Complete!")

	# Wait a brief moment before hiding
	await get_tree().create_timer(0.5).timeout

	# Hide loading overlay
	if loading_overlay:
		loading_overlay.finish()
		loading_overlay = null

	is_loading = false
	loading_completed.emit()
	print("[LoadingManager] Loading completed!")


## Convenience function: update with stage name
func update_progress(stage_name: String, progress: float, status: String = "") -> void:
	var stage: LoadingStage = LoadingStage.RESOURCES

	match stage_name:
		"resources":
			stage = LoadingStage.RESOURCES
		"world":
			stage = LoadingStage.WORLD_GENERATION
		"player":
			stage = LoadingStage.PLAYER_SPAWN
		"camera":
			stage = LoadingStage.CAMERA_SETUP
		"factions":
			stage = LoadingStage.FACTIONS_INIT

	update_stage_progress(stage, progress, status)
