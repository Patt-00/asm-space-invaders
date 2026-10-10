# asm-space-invaders

A deliberately small, modular Space Invaders-style prototype for a Computer Architecture and Organization project. It uses NASM syntax, 16-bit x86 real mode, DOS, BIOS interrupts, and 132×120 SVGA text-mode ASCII graphics. It is a foundation for four developers to extend, not a finished game.

## Architecture

`main.asm` owns program flow: initialize, show a menu, initialize a game, run the update/draw loop, then return to the menu or quit. It includes every module into one source file, which keeps a simple `.COM` build while retaining separate owner-friendly files.

`variables.inc` is the single definition point for all shared state. Modules read or update these variables; no module creates a duplicate copy.

| Area | Responsibility |
| --- | --- |
| `modules/player.asm` | Chef bounds, movement, lives, and timed boost effects |
| `modules/bullet.asm` | Cleaver/rolling pin projectile pool, cooldown, burst, and removal |
| `modules/enemy.asm` | Initial one-enemy setup and future movement hook |
| `modules/collision.asm` | Simple coordinate rectangle collision checks |
| `modules/display.asm` | All BIOS text-mode screen rendering and HUD |
| `modules/menu.asm` | Main-menu, game-over screen, and menu input |
| `modules/features.asm` | Small shield/power-up extension points |
| `assets/*.inc` | ASCII artwork only; no gameplay logic |

## Build

Install NASM using your platform package manager, or download it from [nasm.us](https://www.nasm.us/). From this project directory, run:

```bat
build.bat
```

The exact NASM command is:

```bat
nasm -f bin main.asm -o INVADERS.COM
```

## Run in DOSBox-X

Use DOSBox-X with `machine=svga_s3`: DOSBox 0.74-3 does not support the required SVGA base mode and extended vertical timing. Start DOSBox-X, mount the folder containing this repository, change into it, and run the `.COM` file. For example, on Windows:

```dos
mount c C:\path\to\asm-space-invaders
c:
INVADERS.COM
```

On Termux, run `../run-termux.sh` from this directory to build and launch through Termux X11. The launcher uses DOSBox-X.

On Linux/macOS, mount the full host path in the same way, using the path format accepted by your DOSBox version.

## Controls

| Key | Action |
| --- | --- |
| `Left Arrow` or `A` | Move left |
| `Right Arrow` or `D` | Move right |
| `Space` | Fire cleaver; up to two shots during a boost |
| `X` | Fire rolling pin |
| `Esc` | Quit during play or at a menu |
| `1`, `P`, or `Space` | Start from the main menu |
| `R` or `Space` | Restart at game over |
| `2` or `Q` | Quit from a menu |

## Prototype behavior and limitations

The chef, kitchen cleaver, and rolling pin use the original ASCII artwork from the [Food Invaders document](https://docs.google.com/document/d/12_c8mBJUFdmfvfFPC60TDtMRk0SBgZ7B6iHOYjvszec/edit). The chef renders at its original 12×16 size, including every character and space. Weapon source artwork is also unchanged; the renderer uniformly reduces weapons to 6×8 cells by merging 2×2 source blocks and retaining their occupied strokes. Weapon movement, bounds, and collisions use that smaller footprint. The 132×120 battlefield has 15,840 cells, twice the previous 132×60 area. The unchanged chef now occupies 13.3% of its height instead of 26.7%. VGA vertical timing extends the base mode to 960 scanlines while retaining the same eight-pixel glyphs. The chef is never downsampled. Quitting restores standard 80×25 DOS mode. Frames are composed in memory before being copied to VGA text memory.

Developer 2's player and weapon logic supports three projectile slots, weapon-specific damage, firing cooldowns, lives, and timed movement/damage/fire-rate boosts including a cleaver burst. Cleavers have a 24-frame cooldown (about 1.2 seconds), and rolling pins have a 40-frame cooldown (about 2 seconds); boosted cooldowns are 20 and 32 frames. Both weapons now move three rows per frame, three times their previous speed. Their speed does not alter damage or cooldowns. The three-shot pool and shared cooldown prevent weapon-switch spam. Developer 4 can enable the boost by calling `activate_player_powerup` when a pickup is caught. The current enemy remains static but has eight health points (eight cleavers or four rolling pins): defeating it awards 10 points and ends the demonstration round. Enemy movement/attacks, stage progression, bosses, difficulty selection, and catchable pickup spawning are still integration work for the other owners. See [DEVELOPER2.md](DEVELOPER2.md) for the interfaces and verification. The Termux launcher centers a native 1056×960 window using software output to preserve the glyph proportions and avoid SDL2/OpenGL resize issues; relaunch after rotating the device to recenter it.

## Collision module

Call `check_collisions` after movement updates. It checks weapon hits, chef contact, then bottom breaches, and stops if the game leaves `PLAYING`. Each individual check also guards the game state and ignores a removed enemy. All four public procedures require DS to address the shared variables, take no register arguments, return through shared state, may modify AX and flags, and preserve every other general-purpose register.

| Procedure | Detection and result |
| --- | --- |
| `check_bullet_enemy` | Tests every active 6×8 weapon rectangle against the 5×3 enemy. Consumes colliding shots using `remove_bullet_slot`, applies captured damage, and awards 10 points only on defeat. A lethal hit ends the demo with `GAME_OVER`; later slots remain untouched. |
| `check_enemy_player` | Tests the living enemy against the 12×16 chef. Removes the enemy and calls `player_hit` once, without awarding points or consuming unrelated projectiles. |
| `check_enemy_bottom` | Removes a living enemy and calls `player_hit` when `enemy_y + ENEMY_HEIGHT >= SCREEN_HEIGHT`: its lowest occupied row reaches row 119. Awards no points. |

Hitboxes include all sprite cells, including spaces. Bounds are half-open (`[x, x + width)`, `[y, y + height)`), so adjacent sprites need an occupied cell in common to collide. Endpoint arithmetic uses 16-bit values to avoid byte wraparound. Contact and breaches clear both `enemy_alive` and `enemy_health` before damage, preventing two life deductions in the same frame or repeated checks. If lives remain after removing the only enemy, the prototype stays `PLAYING`; respawning and stage completion are future progression work. The current stationary enemy requires controlled coordinates to exercise contact and breaches.

### Future Food Invaders integration

- Enemy logic will own entity pools, dimensions, health, kill rewards, and a damage procedure. Collision will send damage through that interface and award kill points once. Boss contact needs its own policy rather than removing a boss on chef contact.
- Weapon logic owns projectile pools, captured damage, movement, and consumption. Basic shots consume themselves on the first valid target; secondary piercing or area effects need an explicit policy when introduced. Revisit collision along the movement path if future speeds can skip entire hitboxes.
- Route enemy attack and breach damage through `player_hit`. Player/features logic owns future immunity and shield behavior. Collision will consume caught pickups once; features logic applies effects and manages timers through interfaces such as `activate_player_powerup`.
- Progression logic will own stage completion, boss scheduling, and victory, replacing the demo's `GAME_OVER` on a kill. Collision uses shared dimensions and damage values; difficulty selection and movement rates stay with their respective owners.

### Collision tests

From the project directory, assemble the dedicated harness:

```bat
nasm -f bin tests/collision.asm -o COLLTEST.COM
```

Run `COLLTEST.COM > RESULT.TXT` in DOSBox-X. It needs no graphics mode or keyboard input, prints `PASS` or a specific failure, and exits with status 0 or 1. Tests cover sprite edges/corners and adjacency, projectile slots and damage, life exhaustion, bottom thresholds and overshoot, simultaneous collision priority, repeated checks, non-playing states, byte-limit coordinates, register preservation, and stack balance. The existing `tests/player-bullet.asm` harness covers weapon and rendering integration.

## Team ownership and integration rules

| Developer | Files to modify |
| --- | --- |
| Developer 1 | `main.asm`, `modules/collision.asm`, integration decisions, and shared-interface coordination |
| Developer 2 | `modules/player.asm`, `modules/bullet.asm` |
| Developer 3 | `modules/enemy.asm` |
| Developer 4 | `modules/display.asm`, `modules/menu.asm`, `modules/features.asm`, and `assets/` |

Player/weapon integration also updates `variables.inc`, the input/reset calls in `main.asm`, projectile collision handling, and the display/assets needed for the document artwork. These changes are documented in the handoff; gameplay behavior remains in the player and bullet modules.

1. Define a new shared variable only in `variables.inc`, comment it there, and do not duplicate it in a module.
2. Keep gameplay modules free of BIOS/DOS drawing calls and ASCII art; send all drawing through `display.asm`.
3. Keep each public procedure's header current: purpose, input, output, modified registers, and shared variables.
4. Preserve documented register behavior. Push/pop any register a procedure promises to preserve.
5. Keep module procedure names unique, and call across modules only through their documented procedure interface.
6. Rebuild with `nasm -f bin main.asm -o INVADERS.COM` after integration changes, then test the normal menu-to-game-to-game-over/restart/quit path in DOSBox.
