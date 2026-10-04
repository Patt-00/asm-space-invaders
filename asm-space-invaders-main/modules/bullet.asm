; One player bullet.  A later team can replace this with a bullet array.

; -------------------------------------------------
; Procedure: fire_bullet
; Purpose: Start a bullet at the center of the player sprite.
; Input: None
; Output: bullet_active becomes 1 if no bullet was active.
; Modifies: AX
; Shared variables used: player_x, player_y, bullet_x, bullet_y, bullet_active
; -------------------------------------------------
fire_bullet:
    cmp byte [bullet_active], 0
    jne .done
    mov al, [player_x]
    add al, 2
    mov [bullet_x], al
    mov al, [player_y]
    dec al
    mov [bullet_y], al
    mov byte [bullet_active], 1
.done:
    ret

; -------------------------------------------------
; Procedure: update_bullets
; Purpose: Move the active bullet upward one text row.
; Input: None
; Output: bullet_y may decrease; off-screen bullets are removed.
; Modifies: AX
; Shared variables used: bullet_y, bullet_active
; -------------------------------------------------
update_bullets:
    cmp byte [bullet_active], 1
    jne .done
    cmp byte [bullet_y], 0
    je .remove
    dec byte [bullet_y]
    jmp .done
.remove:
    call remove_bullet
.done:
    ret

; -------------------------------------------------
; Procedure: remove_bullet
; Purpose: Mark the player bullet as unused.
; Input: None
; Output: bullet_active becomes 0.
; Modifies: AX
; Shared variables used: bullet_active
; -------------------------------------------------
remove_bullet:
    mov byte [bullet_active], 0
    ret
