; Shared game data and constants.  This file is included once by main.asm.

SCREEN_WIDTH    equ 132
SCREEN_HEIGHT   equ 120
PLAYFIELD_TOP   equ 1        ; Row zero belongs to the HUD.
PLAYER_WIDTH    equ 12
PLAYER_HEIGHT   equ 16
SOURCE_ART_WIDTH equ 12
SOURCE_ART_HEIGHT equ 16
WEAPON_SCALE    equ 2        ; Reduce only weapon artwork in the renderer.
WEAPON_WIDTH    equ SOURCE_ART_WIDTH / WEAPON_SCALE
WEAPON_HEIGHT   equ SOURCE_ART_HEIGHT / WEAPON_SCALE
BULLET_SPEED    equ 3        ; Rows per update; independent of firing cooldown.

; VGA 32 KiB text memory and 8-bit coordinates bound this display mode.
%if SCREEN_WIDTH != 132 || SCREEN_HEIGHT != 120
    %error "Display timing is configured for 132x120 cells"
%endif
%if SCREEN_WIDTH * SCREEN_HEIGHT * 2 > 32768
    %error "Text frame must fit in VGA text memory"
%endif

; Keep the chef at source size; halve weapon width and height at draw time.
%if PLAYER_WIDTH != SOURCE_ART_WIDTH || PLAYER_HEIGHT != SOURCE_ART_HEIGHT
    %error "Player dimensions must match source artwork dimensions"
%endif
%if WEAPON_SCALE != 2 || WEAPON_WIDTH * WEAPON_SCALE != SOURCE_ART_WIDTH || WEAPON_HEIGHT * WEAPON_SCALE != SOURCE_ART_HEIGHT
    %error "Weapon renderer requires exact 2x2 source blocks"
%endif
%if BULLET_SPEED < 1 || BULLET_SPEED > WEAPON_HEIGHT
    %error "Projectile steps must stay within sprite height to avoid skipped collisions"
%endif
MAX_BULLETS     equ 3
CLEAVER         equ 0
ROLLING_PIN     equ 1
NORMAL_COOLDOWN equ 24        ; Frames; main loop waits roughly 50 ms.
BOOST_COOLDOWN  equ 20
SECONDARY_COOLDOWN equ 40   ; Stronger weapon: a slower two-second cadence.
BOOST_SECONDARY_COOLDOWN equ 32
BOOST_BURST_COUNT equ 2
BOOST_FRAMES    equ 80       ; Roughly four seconds.
INITIAL_ENEMY_HEALTH equ 8   ; Eight cleavers or four rolling pins per demo enemy.

ENEMY_WIDTH     equ 5
ENEMY_HEIGHT    equ 3

MENU            equ 0
PLAYING         equ 1
GAME_OVER       equ 2
QUIT            equ 3

player_x        db (SCREEN_WIDTH - PLAYER_WIDTH) / 2       ; Left column of the player sprite (0 through SCREEN_WIDTH - PLAYER_WIDTH).
player_y        db SCREEN_HEIGHT - PLAYER_HEIGHT - 1       ; Top row of the player sprite (within the playfield).
player_lives    db 3        ; Remaining player lives for future enemy attacks.

; Legacy names alias slot zero; array users index with SI (0..MAX_BULLETS-1).
bullet_x:
bullets_x       times MAX_BULLETS db 0
bullet_y:
bullets_y       times MAX_BULLETS db 0
bullet_active:
bullets_active  times MAX_BULLETS db 0
bullets_kind    times MAX_BULLETS db CLEAVER
bullets_damage  times MAX_BULLETS db 0 ; Damage is captured at firing time.
fire_cooldown   db 0
player_boost_frames dw 0

enemy_x         db (SCREEN_WIDTH - ENEMY_WIDTH) / 2       ; Left column of the prototype enemy sprite.
enemy_y         db 4        ; Top row of the prototype enemy sprite.
enemy_health    db INITIAL_ENEMY_HEALTH        ; Integration: Developer 3 can initialize tougher enemies.
enemy_alive     db 1        ; 0 after the prototype enemy is hit.

score           dw 0        ; Player score; one defeated enemy gives 10 points.
current_wave    db 1        ; Wave number reserved for later enemy groups.
game_state      db MENU     ; MENU, PLAYING, GAME_OVER, or QUIT.

shield_active   db 0        ; Reserved flag for a future shield feature.
powerup_active  db 0        ; 1 while Developer 2's timed boost is active.

; Display-owned state: compose a complete text frame before presenting it.
render_cursor   dw 0
render_buffer   times SCREEN_WIDTH * SCREEN_HEIGHT dw 0720h
