# FACTION MOTHERSHIP SPECIFICATION

## Overview
The faction mothership is a composite entity consisting of a central mothership model and three assembly zones. It serves as the primary hub for squad operations, resource management, and player interaction within the faction's territory.

**CRITICAL**: The entire faction mothership entity MUST be designed as a **fully reusable, instantiable component**. Multiple motherships will be spawned across the game world for different factions and locations.

---

## 1. MOTHERSHIP MODEL

### 1.1 Collision Configuration
- The mothership MUST be spawned with mesh collision only
- NO collision boxes, collision spheres, or interaction areas should be added
- The mesh collision provides the physical boundaries for the mothership

### 1.2 Entity Composition
- The mothership 3D model is a component of the larger faction mothership entity
- The complete entity includes: mothership model + 3 assembly zones + labels

### 1.3 Labeling
- The mothership MUST have a Label3D displaying: `Mothership XYZ [FACTION NAME]`
- Example: "Mothership Alpha [Red Faction]"
- The label should be positioned above the mothership for visibility

---

## 2. ASSEMBLY ZONES

### 2.1 Zone Quantity and Purpose
- There MUST be exactly 3 assembly points positioned AROUND the mothership
- Assembly zones serve multiple purposes:
  - **Starting Point**: Squad spawn/launch location
  - **Resource Offload**: Squads deliver collected resources
  - **Retreat Destination**: Safe haven for damaged/retreating squads

### 2.2 Zone Positioning
- Zones are positioned in a circular pattern around the mothership
- Recommended layout: 120° separation (equidistant spacing)
- Zones should be placed at a safe distance from the mothership to avoid collision interference

### 2.3 Zone Visual Design
- Each zone is a **circular area** on the terrain
- Visual indicator: Neon passable boundary ring
- Height: Rises 3 meters above the terrain with gradient fade
- The gradient provides clear visual feedback without blocking movement

### 2.4 Zone Labeling
- Each assembly zone MUST have a Label3D
- Labels: `Zone 1`, `Zone 2`, `Zone 3`
- Labels should be visible from aerial and ground perspectives

---

## 3. SPAWN PLACEMENT CONSTRAINTS

### 3.1 Boundary Requirements
- The ENTIRE faction mothership entity (mothership + all 3 assembly zones) MUST be spawned within map boundaries
- NO part of the entity may extend outside the map boundaries, neither completely nor partially
- Boundary checks must account for:
  - Mothership model dimensions
  - Assembly zone radius
  - Label visibility space

### 3.2 Terrain Height Detection
- **ALL** mothership faction entity components MUST use **vertical raycasting** to find the appropriate Y position
- This applies to:
  - Mothership model placement
  - Assembly zone positioning
  - Label3D vertical positioning
- Raycasting implementation:
  - Cast ray downward from desired XZ coordinates
  - Detect terrain surface collision
  - Set component Y position based on raycast hit point
  - Account for component-specific height offsets (e.g., assembly zones sit on terrain, labels float above)

### 3.3 Implementation Notes
- Perform boundary validation before spawning
- If placement would violate boundaries, adjust position or fail gracefully
- Raycasting should be performed during spawn initialization
- Handle edge cases where raycast fails (no terrain detected)

---

## 4. PLAYER INTERACTION

### 4.1 Entry Mechanism
- The player can enter the mothership by navigating to any of the 3 assembly zones
- Entry requires: Player remains within zone boundaries for **3 seconds**
- Visual feedback should indicate entry progress (timer/progress bar)

### 4.2 Entry Event
- When entry conditions are met, trigger the `enter_mothership` event
- Event behavior and consequences: **TO BE DEFINED** (pending specification)

---

## 5. CODE ARCHITECTURE PRINCIPLES

### 5.1 File Structure and Organization
- Maintain a **clean file structure** with logical organization
- Separate mothership-related code into dedicated modules/scripts
- Recommended structure:
  - `faction_mothership.gd` - Main entity coordinator
  - `assembly_zone.gd` - Reusable assembly zone component
  - `mothership_labels.gd` - Label management
  - `terrain_placement.gd` - Raycasting and positioning utilities

### 5.2 Separation of Concerns
- **Each script should have a single, well-defined responsibility**
- Mothership entity coordination should be separate from zone logic
- Terrain placement logic should be isolated and testable
- Visual effects (neon gradients) should be encapsulated in dedicated components
- Player interaction detection should be decoupled from entry event handling

### 5.3 Reusability
- **The ENTIRE faction mothership entity MUST be reusable and instantiable**
- Multiple mothership instances will be created throughout the game world
- Each mothership instance must be fully independent with its own:
  - Unique position and orientation
  - Faction-specific labels and identification
  - Three dedicated assembly zones
  - Independent player interaction detection
- **Assembly zones MUST be implemented as reusable components**
- The same zone component should be instantiated 3 times per mothership
- Terrain raycasting utilities should be reusable across different entity types
- Label creation and management should use shared utilities
- Boundary validation logic should be generic and applicable to other entities
- Avoid hardcoded values; use configuration parameters for customization

### 5.4 Design Patterns
- Use composition over inheritance where applicable
- Implement signals/events for decoupled communication
- **Use factory pattern or scene instantiation for mothership creation**
- The mothership should be a scene (.tscn) that can be instantiated multiple times
- Use dependency injection for shared services (terrain detection, boundary validation)
- Parameterize mothership properties (faction name, position, model variant, etc.)

---

## 6. TECHNICAL IMPLEMENTATION CHECKLIST

- [ ] Mothership model with mesh collision only
- [ ] Three assembly zones with circular geometry
- [ ] Neon gradient visual effects (3m height)
- [ ] Label3D for mothership (faction-specific)
- [ ] Label3D for each zone (Zone 1, 2, 3)
- [ ] Boundary validation system
- [ ] Zone occupancy detection (3-second timer)
- [ ] `enter_mothership` event trigger
- [ ] No collision boxes/spheres/interaction areas on mothership
- [ ] Clean file structure with separated concerns
- [ ] Reusable assembly zone component
- [ ] Shared terrain raycasting utilities
- [ ] Entire mothership entity is reusable/instantiable
- [ ] Mothership properties are parameterized (not hardcoded)
- [ ] Multiple motherships can coexist independently
