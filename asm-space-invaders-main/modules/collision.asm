; Coordinate collision logic only; no movement, input, or drawing.
; All procedures require DS to address variables.inc. Hitboxes include sprite spaces.
; Rectangles are half-open: [x, x + width), [y, y + height). Touching is not a hit.
; Extend byte coordinates before endpoint arithmetic so bounds cannot wrap at 255.

; -------------------------------------------------
; Procedure: check_collisions
; Purpose: Check projectile hits, chef contact, then bottom breaches during play.
; Input: None
; Output: Shared state may change; stop checks if play ends.
; Modifies: AX, flags; all other general-purpose registers preserved.
; Shared variables read: game_state and the inputs of the checks below.
; Shared variables written: Outputs of the checks below.
; -------------------------------------------------
check_collisions:
    cmp byte [game_state], PLAYING
    jne .done
    call check_bullet_enemy
    cmp byte [game_state], PLAYING
    jne .done
    call check_enemy_player
    cmp byte [game_state], PLAYING
    jne .done
    call check_enemy_bottom
.done:
    ret

; -------------------------------------------------
; Procedure: check_bullet_enemy
; Purpose: Check every weapon rectangle against the living prototype enemy.
; Input: None
; Output: Hit shots consumed; damage applied; a kill awards 10 and ends the demo.
; Modifies: AX, flags; all other general-purpose registers preserved.
; Shared variables read: game_state, bullets_x/y/active/damage,
;                        enemy_x/y/health/alive, score.
; Shared variables written: bullets_active/damage (via remove_bullet_slot),
;                           enemy_health/alive, score, game_state.
; -------------------------------------------------
check_bullet_enemy:
    cmp byte [game_state], PLAYING
    jne .done
    cmp byte [enemy_alive], 1
    jne .done
    push bx
    push si
    xor si, si
.loop:
    cmp byte [bullets_active + si], 1
    jne .next

    xor ax, ax
    mov al, [bullets_x + si]
    xor bx, bx
    mov bl, [enemy_x]
    add bx, ENEMY_WIDTH
    cmp ax, bx
    jae .next
    sub bx, ENEMY_WIDTH
    add ax, WEAPON_WIDTH
    cmp ax, bx
    jbe .next

    xor ax, ax
    mov al, [bullets_y + si]
    xor bx, bx
    mov bl, [enemy_y]
    add bx, ENEMY_HEIGHT
    cmp ax, bx
    jae .next
    sub bx, ENEMY_HEIGHT
    add ax, WEAPON_HEIGHT
    cmp ax, bx
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
    pop bx
.done:
    ret

; -------------------------------------------------
; Procedure: check_enemy_player
; Purpose: Detect overlap between the living enemy and chef rectangles.
; Input: None
; Output: Remove the enemy, lose one life, and end play if lives reach zero.
;         Score and projectiles are unchanged; a removed enemy cannot hit twice.
; Modifies: AX, flags; all other general-purpose registers preserved.
; Shared variables read: game_state, enemy_x/y/alive, player_x/y, player_lives.
; Shared variables written: enemy_alive/health, player_lives and game_state
;                           (via player_hit).
; -------------------------------------------------
check_enemy_player:
    cmp byte [game_state], PLAYING
    jne .done
    cmp byte [enemy_alive], 1
    jne .done
    push bx

    xor ax, ax
    mov al, [enemy_x]
    xor bx, bx
    mov bl, [player_x]
    add bx, PLAYER_WIDTH
    cmp ax, bx
    jae .restore
    sub bx, PLAYER_WIDTH
    add ax, ENEMY_WIDTH
    cmp ax, bx
    jbe .restore

    xor ax, ax
    mov al, [enemy_y]
    xor bx, bx
    mov bl, [player_y]
    add bx, PLAYER_HEIGHT
    cmp ax, bx
    jae .restore
    sub bx, PLAYER_HEIGHT
    add ax, ENEMY_HEIGHT
    cmp ax, bx
    jbe .restore

    ; Clear the enemy before damage so contact cannot also count as a breach.
    mov byte [enemy_alive], 0
    mov byte [enemy_health], 0
    call player_hit
.restore:
    pop bx
.done:
    ret

; -------------------------------------------------
; Procedure: check_enemy_bottom
; Purpose: Remove an enemy whose lowest occupied row reaches the bottom row.
; Input: None
; Output: Remove the enemy and lose one life, without awarding score.
;         The breach is enemy_y + ENEMY_HEIGHT >= SCREEN_HEIGHT.
; Modifies: AX, flags; all other general-purpose registers preserved.
; Shared variables read: game_state, enemy_y/alive, player_lives.
; Shared variables written: enemy_alive/health, player_lives and game_state
;                           (via player_hit).
; -------------------------------------------------
check_enemy_bottom:
    cmp byte [game_state], PLAYING
    jne .done
    cmp byte [enemy_alive], 1
    jne .done
    xor ax, ax
    mov al, [enemy_y]
    add ax, ENEMY_HEIGHT
    cmp ax, SCREEN_HEIGHT
    jb .done

    mov byte [enemy_alive], 0
    mov byte [enemy_health], 0
    call player_hit
.done:
    ret
