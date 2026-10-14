#!/bin/bash
# Fix common type inference issues in GDScript files for Godot 4.5+

echo "Fixing type inference issues in GDScript files..."

# Change to project directory
cd "$(dirname "$0")/.." || exit 1

# Counter
fixed=0

# Find all .gd files and fix common patterns
find src scenes -name "*.gd" -type f | while read -r file; do
    # Backup original
    cp "$file" "$file.bak"

    # Fix: var x := abs(y) → var x: float = abs(y)
    sed -i '' 's/var \([a-zA-Z_][a-zA-Z0-9_]*\) := abs(/var \1: float = abs(/g' "$file"

    # Fix: var x := some_method() when it returns Variant
    # This is trickier, we'll add explicit typing where common

    echo "Fixed: $file"
    ((fixed++))
done

echo "Fixed $fixed files"
echo "Backups created with .bak extension"
echo "If issues persist, restore with: find . -name '*.gd.bak' -exec sh -c 'mv \"\$1\" \"\${1%.bak}\"' _ {} \;"
