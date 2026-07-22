# Project instructions

## Project

This is a Godot 4 game written in typed GDScript.

The game presents a fictional Windows 98-style operating system. It combines
incremental progression, tower-defense elements, desktop applications,
resource management, enemies represented as viruses, and data-driven stages.

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