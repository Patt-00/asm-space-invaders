; Player movement and damage logic only.  Drawing belongs in display.asm.

; -------------------------------------------------
; Procedure: update_player
; Purpose: Keep the player coordinate inside screen boundaries.
; Input: None
; Output: player_x is clamped to the legal range.
; Modifies: AX
; Shared variables used: player_x
; -------------------------------------------------
update_player:
    cmp byte [player_x], SCREEN_WIDTH - PLAYER_WIDTH
    jbe .done
    mov byte [player_x], SCREEN_WIDTH - PLAYER_WIDTH
.done:
    ret

; -------------------------------------------------
; Procedure: move_player_left
; Purpose: Move the player one text column left.
; Input: None
; Output: player_x may decrease.
; Modifies: AX
; Shared variables used: player_x
; -------------------------------------------------
move_player_left:
    cmp byte [player_x], 0
    je .done
    dec byte [player_x]
.done:
    ret

; -------------------------------------------------
; Procedure: move_player_right
; Purpose: Move the player one text column right.
; Input: None
; Output: player_x may increase.
; Modifies: AX
; Shared variables used: player_x
; -------------------------------------------------
move_player_right:
    cmp byte [player_x], SCREEN_WIDTH - PLAYER_WIDTH
    jae .done
    inc byte [player_x]
.done:
    ret

; -------------------------------------------------
; Procedure: player_hit
; Purpose: Record one hit on the player and enter game over at zero lives.
; Input: None
; Output: player_lives may decrease; game_state may become GAME_OVER.
; Modifies: AX
; Shared variables used: player_lives, game_state
; -------------------------------------------------
player_hit:
    cmp byte [player_lives], 0
    je .done
    dec byte [player_lives]
    jne .done
    mov byte [game_state], GAME_OVER
.done:
    ret
