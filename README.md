# Autonomous Expanse

A 3D sandbox drone game built with Godot 4.5. You fly hover drones over a hostile, procedurally generated planet while rival AI factions mine it and fight over it around you.

## The setting

In 2087, astronomers find **Paradox Prime** (Kepler-442c), a planet 1,200 light-years away that is rich in iridium, platinum and rare earths. Its atmosphere kills a human within minutes. So Earth sends no people. It sends a self-replicating factory seed that builds drones, motherships and an AI to run them, and that AI takes orders through a quantum-entangled communication link.

Decades later, the single governing AI has split into competing factions. Each faction is a machine civilization with its own strategy, mining a world its human sponsors will never visit. Humans on Earth can still take over individual drones remotely through the link. Some of them do it for corporations, some for money and some for the thrill. You are one of those pilots.

Read the full lore in [`docs/lore/`](docs/lore/).

## What you do

- **Fly.** Every drone is a thrust-based hover vehicle. You can hover in place, strafe and climb in any direction, and there are no stall mechanics.
- **Explore.** The terrain is procedural, with mountains, valleys, resource deposits and faction territory.
- **Fight.** Drones carry energy weapons, lasers and burst cannons, with primary and secondary fire.
- **Watch the world run itself.** Faction motherships build drones and organize them into squads. The squads mine, haul cargo, defend their zones and raid rivals without any input from you.

### Drone types

| Drone | Role |
|---|---|
| Cargo | High capacity, durable, lightly armed |
| Explorer | Fast, long range, advanced sensors, minimal weapons |
| Fighter (two variants) | Combat-focused |

## How the AI is organized

The simulation uses a layered AI:

1. **Faction:** manages its economy, mothership and strategy.
2. **Squad:** a priority manager picks a goal (gather, defend, attack) and an executor coordinates the drones carrying it out.
3. **Drone:** handles its own pathfinding, obstacle avoidance, flight control and weapons.

Design specs for each system are in [`docs/specs/`](docs/specs/).

## Running it

You need [Godot 4.5+](https://godotengine.org/).

```sh
make run          # play
make run-editor   # open in the Godot editor
make test         # run test scenes
make help         # list all commands
```

Or open `project.godot` in Godot and press F5.

### Controls

| Action | Input |
|---|---|
| Move | W A S D |
| Climb / descend | Space / Ctrl |
| Boost | Shift |
| Aim | Mouse |
| Fire | Left mouse button |
| Secondary fire | Right mouse button, Q or R |
| Interact | E |
| Reset camera | C |
| Map / inventory | M / I |
| Pause | Esc |

Bindings are configured under Project Settings → Input Map.

## Project layout

```
src/        game code (ai, drones, faction, squad, weapons, world, cameras, ui, ...)
scenes/     Godot scenes
shaders/    drone, thruster, shield and stealth shaders
assets/     drone models, resources and audio
docs/       lore, specs and research
tests/      test scenes and unit tests
```

## Credits

The sound effects come from Kenney's [Sci-Fi Sounds](https://www.kenney.nl) and are licensed CC0.
