# Developer 2 handoff

The player and weapon implementation follows the team's [Food Invaders document](https://docs.google.com/document/d/12_c8mBJUFdmfvfFPC60TDtMRk0SBgZ7B6iHOYjvszec/edit). The weapon artwork and comparison table identify **cleaver / rolling pin**. Some prose says condiment; this implementation follows the explicitly labeled rolling pin artwork and comparison table.

The original 12×16 chef and weapon ASCII artwork remains unchanged in the active asset files. The chef still renders at its full 12×16 size, copying every character and space directly. Only weapons are reduced uniformly to 6×8 cells: each 2×2 source block contributes its first nonblank character, preserving thin strokes and the distinct cleaver/pin outlines. Bounds and collision rectangles use the reduced weapon dimensions. SVGA 132×120 text mode expands the field to 15,840 cells, twice the previous 132×60 area. The 16-row chef now occupies 13.3% of the field height (previously 26.7%). The chef sits at row 103 with 102 rows between the HUD and chef; the bottom row holds controls. Bounds cover whole sprites. Quit restores DOS 80×25 mode. `initialize_display` starts with DOSBox-X’s VESA 132×60 mode and programs the VGA vertical timing for 960 visible scanlines with the same eight-pixel glyphs. It also updates BIOS geometry and allows the initial window resize before drawing the menu. One 31,680-byte frame fits in the 32 KiB VGA text page; geometry assertions prevent overflow. This emulator-specific mode requires DOSBox-X with `machine=svga_s3`; quitting restores standard timings.

The Termux launcher centers the native 1056×960 game window on the current X11 display. This fits the device’s 1080-pixel short edge and preserves square 8×8 character cells. It uses DOSBox-X software output to avoid SDL2/OpenGL resize problems on this device. After the tall raster is ready, the launcher uses `xdotool` to re-expose this emulator’s window and refresh the initial menu; other windows are untouched. Relaunch after changing orientation to recenter the window. The per-launch configuration is temporary; the global DOSBox configuration is unchanged.

## Player and weapon behavior

- A/D or left/right arrows move one column; a boost moves two and clamps at either edge.
- Three lives; `player_hit` subtracts one during play and ends play at zero without wrapping.
- Space fires a cleaver (1 damage). X fires a rolling pin (2 damage). Both share a bounded three-slot projectile pool and cooldown.
- Normal cleaver cooldown is 24 frames (about 1.2 seconds). Rolling-pin cooldown is 40 frames (about 2 seconds), trading higher damage for slower firing. Boosted cooldowns are 20 and 32 frames, respectively. Boost adds one damage to newly fired projectiles rather than doubling the stronger weapon. Boosted Space fires at most two cleavers, spaced apart without overwriting active shots. Repeated input and weapon switching cannot bypass a pending cooldown.
- Projectiles move upward three rows per frame (previously one), independently of the chef. The final movement step clamps to the top playfield row for one visible frame, then removes the shot without coordinate underflow. A compile-time check keeps the movement step within the weapon height so discrete collision checks cannot skip the stationary target. Projectile speed is independent of cooldown ticking, damage, and boost duration.
- `activate_player_powerup` applies all three boost effects for 80 updates (about four seconds with the existing frame delay). Repeated pickups refresh the duration but do not reset a pending attack cooldown. Active shots retain their damage when the boost expires.

Damage, cooldown, pool size, and boost duration are implementation choices because the document supplies no numeric values. Constants live in `variables.inc`.

## Integration interfaces

All procedures require DS to point to the shared-data segment. Procedure headers describe inputs, outputs, shared state, and register changes.

| Caller / owner | Interface |
| --- | --- |
| Developer 1 / new game | Call `initialize_player` and `initialize_bullets` on every new game/restart. |
| Developer 1 / input | Existing `fire_bullet` is the primary entry point; X calls `fire_secondary`. |
| Developer 1 / game loop | Call `update_player` and `update_bullets` once each per frame. Do not call `update_player` from movement code, because it ticks the boost timer. |
| Developer 1 / collision | Iterate all slots; `SI` identifies the slot for `remove_bullet_slot`. Use `bullets_damage + SI` for damage. Sprite coordinates are top-left and collisions include their width/height. |
| Developer 3 / enemies | Initialize `enemy_health` for each enemy. Current prototype initializes it to 8 (eight cleavers or four rolling pins). Collision subtracts damage and removes an enemy at zero health. |
| Developer 4 / pickups | Call `activate_player_powerup` after collecting a pickup. It preserves all registers and flags and ignores calls outside play. Pickup spawning/collection is not implemented by Developer 2. |
| Developer 4 / display | Art is original fixed-width 12×16 data. `draw_sprite` copies every chef character and space at native size. `draw_weapon_sprite` alone reduces 2×2 source blocks to the 6×8 weapon footprint. `draw_bullet` renders all active slots, with cyan cleavers, yellow pins, red boosted shots. HUD shows BOOST while active. |

`bullet_x`, `bullet_y`, and `bullet_active` remain aliases for slot zero, and `remove_bullet` still removes slot zero. Code handling all projectiles must use the arrays and indexed removal. `spawn_player_weapon` returns CF=0 with AX=allocated slot, or CF=1 when blocked.

The player/bullet modules contain no graphics or DOS/BIOS interrupts. Supporting changes in `main.asm`, `variables.inc`, collision, menus, display, and art connect the new behavior to the existing game. Display composes a frame in RAM before presenting it; this remains display-owned code.

## Verification

From the project directory:

```sh
nasm -f bin main.asm -o INVADERS.COM
nasm -f bin tests/player-bullet.asm -o PBTEST.COM
```

Mount the project in DOSBox-X with `machine=svga_s3` and run:

```dos
PBTEST.COM > RESULT.TXT
```

The harness runs 167 checks (163 named assertions, one complete 192-character chef comparison, and three complete 48-character weapon comparisons) and prints `PASS: Food Invaders player, dual weapons, boosts and collision tests`, or stops at the first named failure. Coverage includes movement, whole-sprite boundaries, lives, state guards, both weapons, full/partial projectile pools, cooldowns, burst spawning, boost expiry/refresh, restart reset, damage, all-slot rectangle collisions, register preservation, repeated-input spam protection, cooldown preservation across pickup/weapon switching, frame clearing, and sprite placement/colors at screen edges, all original chef characters and spaces, smaller weapon silhouettes and spacing, faster movement and collision hits, top-edge clamping, BIOS field dimensions, and VGA copies reaching the second half and bottom-right corner of the 120-row field, and eight-cleaver/four-pin target defeats.

The rebuilt game was also checked in DOSBox-X on Termux X11 for both visible weapons, movement, missed shots, enemy hits, game over, restart, and quit. Damage and boost effects are verified in the DOS harness because enemy attacks and pickup collection remain outside this developer's scope.
