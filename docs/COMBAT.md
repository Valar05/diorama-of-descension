# Combat Reference

This document is the fast orientation map for the combat code in the Downloads copy.

## Player State Flow

Primary file:

- `scripts/player.gd`

Important state groups:

- Idle / movement
- Light attack combo
- Slash dash / dash hits
- Parry bounce
- Kick follow-up
- Launcher / elevation
- Hit reaction

### Combo

- The light attack string is loaded from `player_attacks.json`.
- The current light combo has 5 steps.
- Step 5 is `SlashDown`.
- Combo progression is managed by `attack_index`.
- `attack_active` and `attack_timer` control the current move.
- `attack_buffered` lets the next input chain into the current attack.
- Hold input now drives the heavy branch:
  - no combo in progress: `Launcher`
  - 1 hit in the string: `Boot` -> `HeavyStab`
  - 2 hits in the string: `Boot` -> `MultiStab`
  - 3+ hits in the string: `Boot` -> `CrossSlash`
- If hold is pressed during an active light attack, it buffers the heavy branch.
- The buffered branch waits for the current light attack to finish, plays `Boot`, then waits for the boot timer before spawning the follow-up.

### Dash And Meter

- Dash attacks use `dash_slash_hitbox`.
- `dash_meter` fills through successful combat hits.
- When `dash_meter` is full, the next qualifying dash slash deals `dash_meter_full_damage_mult` damage.
- That bonus is consumed on use and resets the meter.
- Parry fills the meter immediately.

### Parry

- Parry is handled through the dash slash hit path.
- On a parry:
  - the enemy still dies
  - the player bounces back instead of passing through
  - the bounce follows the original dash course, not enemy position
  - the dash meter is filled
  - the 5th attack follow-up starts immediately
  - the follow-up suppresses the attack dash for that instance

### Attack Timing

- Input timing uses scaled time in `scaled_input_time`.
- This avoids wall-clock timing drift during attack delay windows.

## Enemy AI Flow

Primary files:

- `scripts/ai_conductor.gd`
- `scripts/melee_enemy.gd`

### Conductor Role

- The conductor coordinates group pressure.
- It assigns attack ownership.
- It keeps enemies from all attacking at once.
- It can also steer retreat and flee behavior.

### Enemy Local State

Enemy state is mostly in `melee_enemy.gd`.

Core states:

- `idle`
- `backing`
- `charging`
- `attacking`
- `returning`
- `cooldown`
- fleeing / pending flee

### Movement Rules

- Enemies chase a move goal from the conductor or player position.
- After attacking, enemies return to pressure distance instead of lingering near the player.
- Wounded enemies flee instead of rejoining the attack loop.
- Move-target changes are debounced to reduce jitter.

### Facing Rules

- Enemy facing now uses one helper.
- The helper prefers horizontal facing when the target is diagonally offset.
- Facing changes also have a short lock so enemies do not rapidly flip between directions.
- This avoids the old bug where enemies below-and-to-the-side would face down too often.

## Testing

Use these from the Downloads copy:

```sh
sh tools/smoke_test_launch.sh
sh tools/hold_combo_test.sh
sh tools/parry_bounce_test.sh
sh tools/parry_followup_test.sh
sh tools/enemy_facing_test.sh
```

Trace support:

```sh
sh tools/ai_trace.sh
```

## Where To Start

- If the player combo or dash feels wrong, start in `scripts/player.gd`.
- If enemies cluster or fail to coordinate, start in `scripts/ai_conductor.gd`.
- If enemy sprites face the wrong way, start in `scripts/melee_enemy.gd`.
- If the project fails to boot, run the smoke test first.
