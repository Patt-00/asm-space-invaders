; Coordinate collision logic.  Width and height constants make larger sprites easy later.

; -------------------------------------------------
; Procedure: check_collisions
; Purpose: Run all collision checks for one game loop iteration.
; Input: None
; Output: Shared state may change after a collision.
; Modifies: AX
; Shared variables used: bullet_active, enemy_alive, player_lives
; -------------------------------------------------
check_collisions:
    call check_bullet_enemy
    call check_enemy_player
    ret

; -------------------------------------------------
; Procedure: check_bullet_enemy
; Purpose: Detect whether the bullet is within the enemy rectangle.
; Input: None
; Output: Enemy is removed, score increases, and game ends when hit.
; Modifies: AX, BX
; Shared variables used: bullet_x, bullet_y, bullet_active, enemy_x, enemy_y,
;                        enemy_alive, score, game_state
; -------------------------------------------------
check_bullet_enemy:
    cmp byte [bullet_active], 1
    jne .done
    cmp byte [enemy_alive], 1
    jne .done

    mov al, [bullet_x]
    cmp al, [enemy_x]
    jb .done
    mov bl, [enemy_x]
    add bl, ENEMY_WIDTH
    cmp al, bl
    jae .done

    mov al, [bullet_y]
    cmp al, [enemy_y]
    jb .done
    mov bl, [enemy_y]
    add bl, ENEMY_HEIGHT
    cmp al, bl
    jae .done

    mov byte [enemy_alive], 0
    call remove_bullet
    add word [score], 10
    ; One defeated enemy completes this architecture demonstration round.
    mov byte [game_state], GAME_OVER
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
