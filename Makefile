# DroneWorld Makefile
# Godot 4.3+ Build and Development Commands

# Configuration
GODOT := godot
PROJECT_DIR := .
PROJECT_FILE := project.godot
EXPORT_DIR := build
LOGS_DIR := logs
GAME_NAME := DroneWorld

# Platform-specific settings
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
    GODOT_PATH := /Applications/Godot.app/Contents/MacOS/Godot
    PLATFORM := macos
    EXPORT_TEMPLATE := macOS
else ifeq ($(UNAME_S),Linux)
    GODOT_PATH := godot
    PLATFORM := linux
    EXPORT_TEMPLATE := Linux/X11
else
    GODOT_PATH := godot
    PLATFORM := windows
    EXPORT_TEMPLATE := Windows Desktop
endif

# Check if custom Godot path is provided
ifdef GODOT_BIN
    GODOT := $(GODOT_BIN)
else ifneq ("$(wildcard $(GODOT_PATH))","")
    GODOT := $(GODOT_PATH)
endif

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
MAGENTA := \033[0;35m
CYAN := \033[0;36m
NC := \033[0m # No Color

# Timestamp
TIMESTAMP := $(shell date +"%Y%m%d_%H%M%S")

.PHONY: help run run-debug run-verbose export clean test check logs setup install-hooks

# Default target
.DEFAULT_GOAL := help

help: ## Show this help message
	@echo "$(CYAN)DroneWorld - Makefile Commands$(NC)"
	@echo ""
	@echo "$(GREEN)Development:$(NC)"
	@echo "  make run           - Run the game normally"
	@echo "  make run-debug     - Run with debug logging"
	@echo "  make run-verbose   - Run with verbose logging (all messages)"
	@echo "  make run-editor    - Open in Godot editor"
	@echo "  make run-profiler  - Run with profiler enabled"
	@echo ""
	@echo "$(GREEN)Testing:$(NC)"
	@echo "  make test          - Run all test scenes"
	@echo "  make test-physics  - Test physics system"
	@echo "  make test-ai       - Test AI system"
	@echo "  make test-camera   - Test camera system"
	@echo "  make check         - Verify project setup"
	@echo ""
	@echo "$(GREEN)Building:$(NC)"
	@echo "  make export        - Export game for current platform"
	@echo "  make export-all    - Export for all platforms"
	@echo "  make export-debug  - Export debug build"
	@echo ""
	@echo "$(GREEN)Maintenance:$(NC)"
	@echo "  make clean         - Clean build artifacts and logs"
	@echo "  make clean-logs    - Clean log files only"
	@echo "  make logs          - View recent logs"
	@echo "  make setup         - Initial project setup"
	@echo "  make install-hooks - Install git hooks"
	@echo ""
	@echo "$(GREEN)Utilities:$(NC)"
	@echo "  make info          - Show project info"
	@echo "  make validate      - Validate all scenes and scripts"
	@echo ""
	@echo "$(YELLOW)Options:$(NC)"
	@echo "  GODOT_BIN=/path/to/godot  - Use custom Godot binary"
	@echo "  SCENE=path/to/scene.tscn  - Run specific scene"
	@echo ""

setup: ## Initial project setup
	@echo "$(CYAN)Setting up DroneWorld project...$(NC)"
	@mkdir -p $(LOGS_DIR)
	@mkdir -p $(EXPORT_DIR)
	@mkdir -p assets/drones
	@mkdir -p assets/environments
	@mkdir -p audio/music
	@mkdir -p audio/sfx
	@echo "$(GREEN)✓ Directories created$(NC)"
	@echo "$(YELLOW)Checking Godot installation...$(NC)"
	@if [ -x "$(GODOT)" ]; then \
		echo "$(GREEN)✓ Godot found at: $(GODOT)$(NC)"; \
		$(GODOT) --version; \
	else \
		echo "$(RED)✗ Godot not found. Please set GODOT_BIN variable.$(NC)"; \
		echo "$(YELLOW)Example: make run GODOT_BIN=/path/to/godot$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)✓ Setup complete!$(NC)"

run: ## Run the game normally
	@echo "$(CYAN)Running DroneWorld...$(NC)"
	@mkdir -p $(LOGS_DIR)
	$(GODOT) --path $(PROJECT_DIR) 2>&1 | tee $(LOGS_DIR)/run_$(TIMESTAMP).log

run-debug: ## Run with debug logging enabled
	@echo "$(CYAN)Running DroneWorld with debug logging...$(NC)"
	@mkdir -p $(LOGS_DIR)
	$(GODOT) --path $(PROJECT_DIR) --verbose 2>&1 | tee $(LOGS_DIR)/debug_$(TIMESTAMP).log

run-verbose: ## Run with verbose logging (all messages)
	@echo "$(CYAN)Running DroneWorld with verbose logging...$(NC)"
	@mkdir -p $(LOGS_DIR)
	$(GODOT) --path $(PROJECT_DIR) -v 2>&1 | tee $(LOGS_DIR)/verbose_$(TIMESTAMP).log

run-editor: ## Open project in Godot editor
	@echo "$(CYAN)Opening DroneWorld in Godot editor...$(NC)"
	$(GODOT) --path $(PROJECT_DIR) --editor &

run-profiler: ## Run with profiler enabled
	@echo "$(CYAN)Running DroneWorld with profiler...$(NC)"
	@mkdir -p $(LOGS_DIR)
	$(GODOT) --path $(PROJECT_DIR) --debug-collisions --debug-navigation --verbose 2>&1 | tee $(LOGS_DIR)/profiler_$(TIMESTAMP).log

run-scene: ## Run specific scene (use SCENE=path/to/scene.tscn)
	@echo "$(CYAN)Running scene: $(SCENE)$(NC)"
	@mkdir -p $(LOGS_DIR)
	$(GODOT) --path $(PROJECT_DIR) $(SCENE) 2>&1 | tee $(LOGS_DIR)/scene_$(TIMESTAMP).log

test: ## Run all test scenes
	@echo "$(CYAN)Running all tests...$(NC)"
	@mkdir -p $(LOGS_DIR)
	@echo "$(YELLOW)Testing project setup...$(NC)"
	$(GODOT) --path $(PROJECT_DIR) --headless -s tests/verify_setup.gd 2>&1 | tee $(LOGS_DIR)/test_$(TIMESTAMP).log
	@echo "$(YELLOW)Testing math utilities...$(NC)"
	$(GODOT) --path $(PROJECT_DIR) --headless -s tests/test_math_utils.gd 2>&1 | tee -a $(LOGS_DIR)/test_$(TIMESTAMP).log
	@echo "$(YELLOW)Testing autoloads...$(NC)"
	$(GODOT) --path $(PROJECT_DIR) --headless -s tests/test_autoloads.gd 2>&1 | tee -a $(LOGS_DIR)/test_$(TIMESTAMP).log
	@echo "$(GREEN)✓ All tests complete!$(NC)"

test-physics: ## Test physics system
	@echo "$(CYAN)Testing physics system...$(NC)"
	@mkdir -p $(LOGS_DIR)
	$(GODOT) --path $(PROJECT_DIR) --headless -s tests/test_drone_camera.gd 2>&1 | tee $(LOGS_DIR)/test_physics_$(TIMESTAMP).log

test-ai: ## Test AI system
	@echo "$(CYAN)Testing AI system...$(NC)"
	@mkdir -p $(LOGS_DIR)
	@echo "$(YELLOW)AI test scene not yet created. Run 'make run-scene SCENE=scenes/main.tscn' to test AI manually.$(NC)"

test-camera: ## Test camera system
	@echo "$(CYAN)Testing camera system...$(NC)"
	@mkdir -p $(LOGS_DIR)
	$(GODOT) --path $(PROJECT_DIR) --headless -s tests/test_drone_camera.gd 2>&1 | tee $(LOGS_DIR)/test_camera_$(TIMESTAMP).log

check: ## Verify project setup and configuration
	@echo "$(CYAN)Verifying DroneWorld setup...$(NC)"
	@mkdir -p $(LOGS_DIR)
	$(GODOT) --path $(PROJECT_DIR) --headless -s tests/verify_setup.gd 2>&1 | tee $(LOGS_DIR)/check_$(TIMESTAMP).log

validate: ## Validate all scenes and scripts for errors
	@echo "$(CYAN)Validating project files...$(NC)"
	@mkdir -p $(LOGS_DIR)
	@echo "$(YELLOW)Checking for script errors...$(NC)"
	@find src -name "*.gd" -type f | while read file; do \
		echo "Checking $$file..."; \
		$(GODOT) --path $(PROJECT_DIR) --headless --check-only -s "$$file" 2>&1 | grep -i "error" && exit 1 || true; \
	done
	@echo "$(GREEN)✓ Validation complete!$(NC)"

export: ## Export game for current platform
	@echo "$(CYAN)Exporting DroneWorld for $(PLATFORM)...$(NC)"
	@mkdir -p $(EXPORT_DIR)/$(PLATFORM)
	$(GODOT) --path $(PROJECT_DIR) --headless --export-release "$(EXPORT_TEMPLATE)" $(EXPORT_DIR)/$(PLATFORM)/$(GAME_NAME) 2>&1 | tee $(LOGS_DIR)/export_$(PLATFORM)_$(TIMESTAMP).log
	@echo "$(GREEN)✓ Export complete: $(EXPORT_DIR)/$(PLATFORM)/$(NC)"

export-debug: ## Export debug build with console
	@echo "$(CYAN)Exporting debug build for $(PLATFORM)...$(NC)"
	@mkdir -p $(EXPORT_DIR)/$(PLATFORM)_debug
	$(GODOT) --path $(PROJECT_DIR) --headless --export-debug "$(EXPORT_TEMPLATE)" $(EXPORT_DIR)/$(PLATFORM)_debug/$(GAME_NAME) 2>&1 | tee $(LOGS_DIR)/export_debug_$(TIMESTAMP).log
	@echo "$(GREEN)✓ Debug export complete: $(EXPORT_DIR)/$(PLATFORM)_debug/$(NC)"

export-all: ## Export for all configured platforms
	@echo "$(CYAN)Exporting for all platforms...$(NC)"
	@echo "$(YELLOW)Note: Requires export templates to be installed$(NC)"
	@make export EXPORT_TEMPLATE="macOS"
	@make export EXPORT_TEMPLATE="Linux/X11"
	@make export EXPORT_TEMPLATE="Windows Desktop"
	@echo "$(GREEN)✓ All exports complete!$(NC)"

clean: ## Clean all build artifacts and logs
	@echo "$(CYAN)Cleaning DroneWorld build artifacts...$(NC)"
	@rm -rf $(EXPORT_DIR)
	@rm -rf $(LOGS_DIR)
	@rm -rf .godot/exported
	@rm -rf .import
	@find . -name "*.import" -type f -delete
	@echo "$(GREEN)✓ Clean complete!$(NC)"

clean-logs: ## Clean log files only
	@echo "$(CYAN)Cleaning log files...$(NC)"
	@rm -rf $(LOGS_DIR)
	@mkdir -p $(LOGS_DIR)
	@echo "$(GREEN)✓ Logs cleaned!$(NC)"

logs: ## View recent logs
	@echo "$(CYAN)Recent log files:$(NC)"
	@if [ -d "$(LOGS_DIR)" ]; then \
		ls -lht $(LOGS_DIR) | head -10; \
		echo ""; \
		echo "$(YELLOW)To view a log file: cat $(LOGS_DIR)/filename.log$(NC)"; \
		echo "$(YELLOW)To tail latest log: tail -f $(LOGS_DIR)/$$(ls -t $(LOGS_DIR) | head -1)$(NC)"; \
	else \
		echo "$(RED)No logs found. Run the game first with 'make run'$(NC)"; \
	fi

logs-tail: ## Tail the most recent log file
	@if [ -d "$(LOGS_DIR)" ] && [ -n "$$(ls -A $(LOGS_DIR) 2>/dev/null)" ]; then \
		echo "$(CYAN)Tailing latest log...$(NC)"; \
		tail -f $(LOGS_DIR)/$$(ls -t $(LOGS_DIR) | head -1); \
	else \
		echo "$(RED)No logs found. Run the game first with 'make run'$(NC)"; \
	fi

info: ## Show project information
	@echo "$(CYAN)DroneWorld Project Information$(NC)"
	@echo "$(YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@echo "$(GREEN)Project:$(NC)       $(GAME_NAME)"
	@echo "$(GREEN)Platform:$(NC)      $(PLATFORM)"
	@echo "$(GREEN)Godot Path:$(NC)    $(GODOT)"
	@if [ -x "$(GODOT)" ]; then \
		echo "$(GREEN)Godot Version:$(NC) $$($(GODOT) --version)"; \
	fi
	@echo "$(GREEN)Project Dir:$(NC)   $(PROJECT_DIR)"
	@echo "$(GREEN)Export Dir:$(NC)    $(EXPORT_DIR)"
	@echo "$(GREEN)Logs Dir:$(NC)      $(LOGS_DIR)"
	@echo "$(YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@echo "$(GREEN)Statistics:$(NC)"
	@echo "  GDScript files: $$(find src -name '*.gd' | wc -l)"
	@echo "  Scene files:    $$(find scenes -name '*.tscn' | wc -l)"
	@echo "  Shader files:   $$(find shaders -name '*.gdshader' 2>/dev/null | wc -l)"
	@echo "  Test files:     $$(find tests -name '*.gd' 2>/dev/null | wc -l)"
	@if [ -d "$(LOGS_DIR)" ]; then \
		echo "  Log files:      $$(ls $(LOGS_DIR) 2>/dev/null | wc -l)"; \
	fi
	@echo "$(YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"

install-hooks: ## Install git hooks for development
	@echo "$(CYAN)Installing git hooks...$(NC)"
	@mkdir -p .git/hooks
	@echo "#!/bin/sh" > .git/hooks/pre-commit
	@echo "# DroneWorld pre-commit hook" >> .git/hooks/pre-commit
	@echo "make validate" >> .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
	@echo "$(GREEN)✓ Git hooks installed!$(NC)"

# Quick aliases
.PHONY: r rd rv e t c
r: run
rd: run-debug
rv: run-verbose
e: run-editor
t: test
c: clean
