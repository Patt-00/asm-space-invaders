; Shared game data and constants.  This file is included once by main.asm.

SCREEN_WIDTH    equ 80
PLAYER_WIDTH    equ 5
ENEMY_WIDTH     equ 5
ENEMY_HEIGHT    equ 3

MENU            equ 0
PLAYING         equ 1
GAME_OVER       equ 2
QUIT            equ 3

player_x        db 38       ; Left column of the player sprite (0-79).
player_y        db 22       ; Top row of the player sprite (0-24).
player_lives    db 3        ; Remaining player lives for future enemy attacks.

bullet_x        db 0        ; Column of the one player bullet.
bullet_y        db 0        ; Row of the one player bullet.
bullet_active   db 0        ; 0 = no bullet; 1 = bullet is moving.

enemy_x         db 37       ; Left column of the prototype enemy sprite.
enemy_y         db 4        ; Top row of the prototype enemy sprite.
enemy_alive     db 1        ; 0 after the prototype enemy is hit.

score           dw 0        ; Player score; one defeated enemy gives 10 points.
current_wave    db 1        ; Wave number reserved for later enemy groups.
game_state      db MENU     ; MENU, PLAYING, GAME_OVER, or QUIT.

shield_active   db 0        ; Reserved flag for a future shield feature.
powerup_active  db 0        ; Reserved flag for future power-ups.
