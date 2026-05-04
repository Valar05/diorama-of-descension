# Diorama of Descension

2D sprite-based character action project in Godot.

This repo is the Downloads copy that should be used for active work and editor import. It is the sibling project to Gravity Fist, but this one is the 2D/diorama branch.

## Current Game Direction

- Flat 2D sprite combat, not Blender-dependent.
- Character-action pacing with a combo string, dash attacks, parries, and launcher states.
- Enemies should feel threatening through AI coordination, not just raw numbers.
- The project is being tuned for mobile-friendly iteration and content generation.

## Core Combat Rules

- The player has a light attack string of 5 attacks.
- The 5th light attack is the downward slash, `SlashDown`.
- Hold input now drives the heavy branch:
  - no combo in progress: `Launcher`
  - 1 hit in the string: `Boot` -> `HeavyStab`
  - 2 hits in the string: `Boot` -> `MultiStab`
  - 3+ hits in the string: `Boot` -> `CrossSlash`
- Hold uses a `0.2s` activation threshold for the heavy branch.
- Hold during an active light attack buffers the heavy branch until that light attack finishes.
- `Boot` must get its own beat, then a separate tap is required to fire the stab/cross-slash follow-up.
- The follow-up tap has its own generous input window after `Boot`.
- Dash has a meter.
- When the dash meter is full, the next qualifying dash slash deals 2x standard attack damage.
- That bonus consumes the meter and resets it.
- Successful parry fills the dash meter immediately.
- Parry still kills the enemy on contact.
- Parry bounce does not let the player pass through the enemy; it bounces the player back.
- The bounce follows the original dash course, not the enemy position.
- Parry now triggers `SlashDown` immediately and suppresses the attack dash for that follow-up.

## AI Direction

- `scripts/ai_conductor.gd` coordinates enemy pressure and attack ownership.
- `scripts/melee_enemy.gd` owns local enemy behavior, but it now obeys conductor control.
- Enemies should:
  - avoid dogpiling
  - keep space around the player
  - attack one at a time
  - retreat after attacking
  - flee when wounded

## Facing Fix

- Enemy facing is centralized in `scripts/melee_enemy.gd`.
- The old problem was enemies below-and-to-the-side snapping face-down too often.
- Facing now biases horizontally in diagonal cases so side attacks are less visually ambiguous.
- Facing changes are also lightly debounced so enemies do not flip directions every frame.

## Important Files

- `project.godot`: Godot project entry point
- `scenes/main.tscn`: main scene
- `scripts/player.gd`: player combat, dash, parry, combo flow
- `scripts/melee_enemy.gd`: enemy AI and facing
- `scripts/ai_conductor.gd`: enemy coordination and pressure control
- `player_attacks.json`: attack data and combo definitions

## Tests And Smoke Checks

Use these from the Downloads copy:

```sh
sh tools/smoke_test_launch.sh
sh tools/hold_combo_test.sh
sh tools/player_death_test.sh
sh tools/parry_bounce_test.sh
sh tools/parry_followup_test.sh
sh tools/enemy_facing_test.sh
```

There is also a trace helper for AI state inspection:

```sh
sh tools/ai_trace.sh
```

## Working Rules

- Use the Downloads copy for active work.
- Do not switch back to the home copy for edits.
- Prefer small regression tests when changing combat behavior.
- If combat behavior changes, update the tests and this document together.

## Good Starting Points

- If combat feels wrong, inspect `scripts/player.gd` first.
- If enemies are clustering or stuttering, inspect `scripts/ai_conductor.gd` and `scripts/melee_enemy.gd`.
- If launch fails, run `tools/smoke_test_launch.sh` before doing anything else.
