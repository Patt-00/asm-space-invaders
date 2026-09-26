# asm-space-invaders

A deliberately small, modular Space Invaders-style prototype for a Computer Architecture and Organization project. It uses NASM syntax, 16-bit x86 real mode, DOS, BIOS interrupts, and 80x25 text-mode ASCII graphics. It is a foundation for four developers to extend, not a finished game.

## Architecture

`main.asm` owns program flow: initialize, show a menu, initialize a game, run the update/draw loop, then return to the menu or quit. It includes every module into one source file, which keeps a simple `.COM` build while retaining separate owner-friendly files.

`variables.inc` is the single definition point for all shared state. Modules read or update these variables; no module creates a duplicate copy.

| Area | Responsibility |
| --- | --- |
| `modules/player.asm` | Player bounds, movement, and damage handling |
| `modules/bullet.asm` | One player bullet: fire, update, remove |
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

## Run in DOSBox

Start DOSBox, mount the folder containing this repository, change into it, and run the `.COM` file. For example, on Windows:

```dos
mount c C:\path\to\asm-space-invaders
c:
INVADERS.COM
```

On Linux/macOS, mount the full host path in the same way, using the path format accepted by your DOSBox version.

## Controls

| Key | Action |
| --- | --- |
| `Left Arrow` or `A` | Move left |
| `Right Arrow` or `D` | Move right |
| `Space` | Fire one bullet |
| `Esc` | Quit during play or at a menu |
| `1`, `P`, or `Space` | Start from the main menu |
| `R` or `Space` | Restart at game over |
| `2` or `Q` | Quit from a menu |

## Prototype behavior and limitations

The game proves the architecture end to end: menu, visible player, left/right movement, one upward-moving bullet, one enemy, coordinate collision, score, lives variable, game-over state, restart, and quit. Hitting the one enemy awards 10 points and ends the demonstration round. The enemy does not move or attack yet, and `check_enemy_player` plus feature updates are intentionally documented placeholders. There are no sounds, multiple enemies, advanced AI, power-ups, animation, bosses, or multiplayer.

## Team ownership and integration rules

| Developer | Files to modify |
| --- | --- |
| Developer 1 | `main.asm`, `modules/collision.asm`, integration decisions, and shared-interface coordination |
| Developer 2 | `modules/player.asm`, `modules/bullet.asm` |
| Developer 3 | `modules/enemy.asm` |
| Developer 4 | `modules/display.asm`, `modules/menu.asm`, `modules/features.asm`, and `assets/` |

1. Define a new shared variable only in `variables.inc`, comment it there, and do not duplicate it in a module.
2. Keep gameplay modules free of BIOS/DOS drawing calls and ASCII art; send all drawing through `display.asm`.
3. Keep each public procedure's header current: purpose, input, output, modified registers, and shared variables.
4. Preserve documented register behavior. Push/pop any register a procedure promises to preserve.
5. Keep module procedure names unique, and call across modules only through their documented procedure interface.
6. Rebuild with `nasm -f bin main.asm -o INVADERS.COM` after integration changes, then test the normal menu-to-game-to-game-over/restart/quit path in DOSBox.
