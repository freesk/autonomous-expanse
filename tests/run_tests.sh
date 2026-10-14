#!/bin/bash

# Test runner for Godot project
# Usage: ./tests/run_tests.sh

cd "$(dirname "$0")/.."

echo "Running SquadPriorityManager tests..."
echo ""

/Applications/Godot.app/Contents/MacOS/Godot --headless --script tests/ai/squad/test_squad_priority_manager.gd 2>&1

echo ""
echo "Tests complete!"
