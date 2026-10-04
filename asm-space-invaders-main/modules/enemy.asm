; Prototype enemy logic.  This module owns enemy movement, never screen output.

; -------------------------------------------------
; Procedure: initialize_enemies
; Purpose: Set up the small initial enemy group (one enemy for now).
; Input: None
; Output: enemy coordinates and alive flag are initialized.
; Modifies: AX
; Shared variables used: enemy_x, enemy_y, enemy_alive
; -------------------------------------------------
initialize_enemies:
    mov byte [enemy_x], 37
    mov byte [enemy_y], 4
    mov byte [enemy_alive], 1
    ret

; -------------------------------------------------
; Procedure: update_enemies
; Purpose: Update enemy state once per game loop.
; Input: None
; Output: Enemy state is ready for drawing/collision.
; Modifies: AX
; Shared variables used: enemy_alive
; -------------------------------------------------
update_enemies:
    cmp byte [enemy_alive], 0
    je .done
    call move_enemies
.done:
    ret

; -------------------------------------------------
; Procedure: move_enemies
; Purpose: Provide the future extension point for enemy movement.
; Input: None
; Output: No movement in this first prototype.
; Modifies: None
; Shared variables used: enemy_x, enemy_y
; -------------------------------------------------
move_enemies:
    ret
