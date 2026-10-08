; Coordinate collision logic.  Width and height constants make larger sprites easy later.

; -------------------------------------------------
; Procedure: check_collisions
; Purpose: Run all collision checks for one game loop iteration.
; Input: None
; Output: Shared state may change after a collision.
; Modifies: AX, BX, flags
; Shared variables used: bullets_active, enemy_alive, enemy_health, player_lives
; -------------------------------------------------
check_collisions:
    call check_bullet_enemy
    call check_enemy_player
    ret

; -------------------------------------------------
; Procedure: check_bullet_enemy
; Purpose: Rectangle collision for all projectile sprites against the prototype enemy.
; Input: None. Output: Hit shots removed; damage applied; dead enemy awards score.
; Modifies: AX, BX, flags (SI preserved).
; Shared: bullets_x/y/active/damage, enemy_x/y/health/alive, score, game_state.
; -------------------------------------------------
check_bullet_enemy:
    cmp byte [enemy_alive], 1
    jne .done
    push si
    xor si, si
.loop:
    cmp byte [bullets_active + si], 1
    jne .next
    mov al, [bullets_x + si]
    mov bl, [enemy_x]
    add bl, ENEMY_WIDTH
    cmp al, bl
    jae .next
    add al, WEAPON_WIDTH
    cmp al, [enemy_x]
    jbe .next
    mov al, [bullets_y + si]
    mov bl, [enemy_y]
    add bl, ENEMY_HEIGHT
    cmp al, bl
    jae .next
    add al, WEAPON_HEIGHT
    cmp al, [enemy_y]
    jbe .next
    mov al, [bullets_damage + si]
    call remove_bullet_slot
    cmp al, [enemy_health]
    jae .defeated
    sub [enemy_health], al
    jmp .next
.defeated:
    mov byte [enemy_health], 0
    mov byte [enemy_alive], 0
    add word [score], 10
    ; Stage progression remains Developer 1's integration responsibility.
    mov byte [game_state], GAME_OVER
    jmp .restore
.next:
    inc si
    cmp si, MAX_BULLETS
    jb .loop
.restore:
    pop si
.done:
    ret

; -------------------------------------------------
; Procedure: check_enemy_player
; Purpose: Reserve a clear place for future enemy-to-player collision logic.
; Input: None
; Output: None in this static-enemy prototype.
; Modifies: None
; Shared variables used: enemy_x, enemy_y, player_x, player_y, player_lives
; -------------------------------------------------
check_enemy_player:
    ret
