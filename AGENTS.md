# Project instructions

## Project

This is a Godot 4 game written in typed GDScript.

The game presents a fictional Windows 98-style operating system. It combines
incremental progression, tower-defense elements, desktop applications,
resource management, enemies represented as viruses, and data-driven daily
waves driven by a fictional in-game clock.

## Architecture

- Apply object-oriented programming principles.
- Prefer single-responsibility classes.
- Prefer composition over deep inheritance.
- Keep gameplay logic separate from UI presentation.
- Use signals for loosely coupled communication where appropriate.
- Avoid multipurpose managers and god objects.
- Do not introduce new autoloads without justification.
- Preserve existing public APIs unless the task requires changing them.
- Prefer data-driven Resources for configurable gameplay content.
- Treat `GameClockState` as the only source of fictional game time.
  `GameClockManager` is the only component that advances it.
- Treat `GameOverclockState` as the owner of overclock phase, timers,
  instruction and active multiplier. `OverclockManager` is the only component
  that advances its gameplay seconds.
- Apply temporary income bonuses centrally in `GameEconomyState`. Productive
  income commands may use the multiplier; spending, refunds, reset and restore
  must remain unmodified.
- Configure enemy progression through `WaveSequenceData`, `DailyWaveData`,
  `WaveEnemyEntry`, and `EnemyArchetypeData`; do not reintroduce elapsed-time
  progression parallel to the daily-wave system.
- Keep `GameState` as the single gameplay-state autoload and typed state
  container. It must not expose domain property proxies, command wrappers, file
  I/O, profile APIs, or signal relays.
- Keep `ProfileService` limited to profile metadata, persistent file access and
  pending new/load scene-transition intent. It must not own gameplay state.
- Build saves from semantic, versioned snapshots. Never serialize Nodes,
  Resources, PackedScenes, Callables, Signals or instance IDs.
- Resolve persistent apps, upgrades and enemy archetypes through
  `GameContentRegistry`; do not persist display names or array positions as
  identity.
- Treat `FirewallNavigationManager` as the single runtime registry and
  navigation owner for established Firewall windows. Mobile Firewalls and
  ordinary `AppWindow` instances must not become navigation obstacles.
- Keep Firewall navigation revisions pending until `NavigationServer2D` has
  synchronized the rebuilt map. Invalidate every enemy path on obstacle changes,
  keep the synchronized obstacle snapshot aligned with that revision, and do not
  resume a restored session while navigation is pending.
- Treat `EnemyManager` as the single runtime registry for `slowdown.exe` areas.
  Slowdown modifies only the derived movement multiplier on `DesktopVirus`; it
  must not mutate `EnemyRuntimeStats`, navigation, attacks or persisted enemy data.
- Treat `WindowManager` as the only runtime source of Adware hiding candidates
  and as the lifecycle owner of generated `SpamWindow` instances. Adware must not
  reserve RAM, maintain a second window registry or persist Node references.
- Coordinate capture and restore in `DesktopSaveCoordinator`; UI nodes and
  gameplay entities must not read or write save files directly.
- Resolve required specialized states once during consumer initialization and
  retain only those typed references. Managers and windows must not retain the
  complete `GameState` container.
- Specialized states own their data, clamps, invariants, mutation commands, and
  domain signals. Consumers must not write protected state fields directly.
- Connect state observers to the specialized state that owns the signal.

## GDScript

- Use Godot 4 syntax.
- Use static typing wherever practical.
- Add explicit return types.
- Avoid inferred Variant values when a concrete type is available.
- Use snake_case for variables and methods.
- Use PascalCase for class names.
- Prefer guard clauses over deeply nested conditionals.
- Do not add comments that merely repeat the code.

## Godot files

- Inspect related `.gd`, `.tscn`, `.tres`, and `project.godot` references
  before making changes.
- Do not rename nodes, scripts, signals, exported properties, or resources
  without finding all references.
- Be conservative when editing scene and resource files.
- Do not modify generated files inside `.godot/`.
- Do not delete assets or files unless explicitly requested.

## Workflow

Before modifying files:

1. Inspect the relevant implementation and references.
2. Summarize the current behavior.
3. Identify the files that need to change.
4. Explain architectural decisions and risks.
5. Prefer the smallest coherent change.

For broad changes, present a plan before editing.

After modifying files:

1. Review the complete diff.
2. Search for broken references.
3. Report every modified file.
4. Run available validation.
5. Clearly state what was not tested.

## Safety

- Do not perform unrelated cleanup.
- Do not install dependencies without approval.
- Do not alter Git history.
- Do not commit or push unless explicitly requested.
- Do not claim runtime validation succeeded unless Godot was actually run.

## Project documentation

Project documentation is part of the implementation and must remain consistent
with the codebase.

Before working:

1. Always read this `AGENTS.md`.
2. Read `README.md` when starting a new thread or when general project context is
   needed.
3. Read only the domain documents relevant to the task:

   * `docs/PROJECT_OVERVIEW.md` for product intent, gameplay loop, implemented,
     partial and planned features.
   * `docs/ARCHITECTURE.md` for ownership, dependencies, managers, autoloads and
     architectural boundaries.
   * `docs/GAMEPLAY_SYSTEMS.md` for observable gameplay rules.
   * `docs/DATA_MODEL.md` for Resources, IDs, configuration and runtime state.
   * `docs/SIGNALS.md` for signal contracts, emitters and consumers.
4. Inspect the actual scripts, scenes and Resources involved. Documentation is
   context, not a substitute for reading the implementation.
5. Do not resolve questions marked as `Unknown` or identified with a question ID
   without user confirmation when the task depends on them.

After implementing:

1. Determine whether the change made any documentation inaccurate.
2. Update only the documents and sections affected by the change.
3. Do not rewrite unrelated documentation.
4. Preserve the distinction between:

   * Implemented
   * Partially implemented
   * Planned
   * Unknown
5. Update source paths, signal contracts, ownership descriptions and configuration
   values when they change.
6. If no documentation update is necessary, state why.
7. Report documentation changes separately from code changes.

A task is not complete when the implementation contradicts the documentation.
