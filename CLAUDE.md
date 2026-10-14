# DroneWorld Project Instructions

## Critical Development Rules

### Testing Policy

**CRITICAL: NEVER ASK THE USER TO TEST SOMETHING IF YOU CAN DO IT YOURSELF**

- Always run tests, builds, and verification steps yourself before presenting work
- If the code can be executed, simulated, or verified programmatically, DO IT
- Only ask the user to test when:
  - Interactive gameplay testing is required (actual gameplay feel, UX feedback)
  - Visual/aesthetic feedback is needed (does it look right?)
  - Hardware-specific testing is required that you cannot access
- When making changes:
  1. Make the change
  2. Run the Godot editor if needed to verify scene/script validity
  3. Check for errors and warnings
  4. Fix any issues found
  5. Present the working solution to the user

### Why This Matters

- Users expect working code, not homework assignments
- You have direct access to the Godot engine and can verify most changes
- Asking users to test things you can verify yourself wastes their time
- Catching errors before presentation builds trust and efficiency
