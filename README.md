# Developer 2 Contribution — Player and Weapons

Developer 2 implements the Chef's movement, lives, weapons, projectiles, and temporary player boost effects for Food Invaders. The main gameplay files are `asm-space-invaders-main/modules/player.asm` and `asm-space-invaders-main/modules/bullet.asm`.

## Implemented work

- **Chef movement:** A/D or the left/right arrow keys move the Chef horizontally. Boundary checks keep the entire Chef sprite inside the playfield.
- **Player lives:** The player starts with three lives. `player_hit` removes one life during gameplay and changes the game state to game over when no lives remain.
- **Primary weapon:** Space fires a cleaver with one damage point.
- **Secondary weapon:** X fires a rolling pin with two damage points and a longer firing cooldown.
- **Projectile handling:** A shared pool supports up to three active projectiles. Projectiles move upward, are removed at the screen boundary, and do not overwrite occupied slots.
- **Attack cooldowns:** Both weapons share a cooldown so repeated input or weapon switching cannot bypass the firing delay.
- **Temporary boosts:** `activate_player_powerup` enables faster movement, increased damage, shorter firing cooldowns, and a two-cleaver burst for 80 game-loop updates. Repeated activation refreshes the duration. The boost expires automatically.
- **Restart reset:** Initialization restores the Chef's position and lives, clears boost state, removes active shots, and resets firing cooldowns.
- **Integration support:** Supporting changes connect the new controls, reset routines, weapon damage, projectile collisions, Chef/weapon ASCII art, and HUD feedback to the existing prototype. Display changes compose a text frame in RAM and copy it to VGA text memory. A Termux X11 launcher supports the DOSBox-X display setup.
- **Tests:** `asm-space-invaders-main/tests/player-bullet.asm` provides an Assembly test harness for movement, lives, weapons, projectile bounds, cooldowns, boosts, reset behavior, collisions, and rendering support.

## Functions for group integration

- Call `initialize_player` and `initialize_bullets` when starting or restarting a game.
- Call `update_player` and `update_bullets` once per game-loop update.
- Call `fire_bullet` for the primary attack and `fire_secondary` for the secondary attack.
- Call `player_hit` when enemy logic detects damage to the Chef.
- Call `activate_player_powerup` when the pickup system detects a collected power-up.
- Use the projectile arrays and `bullets_damage` for collision checks. Pass the projectile slot in `SI` to `remove_bullet_slot` when removing a shot.

Developer 2 supplies the player-side damage and boost functions. Enemy movement and attacks, pickup spawning and collection, stage progression, difficulty selection, and boss behavior require integration by their assigned developers.

The current integrated display requires DOSBox-X with `machine=svga_s3`.
