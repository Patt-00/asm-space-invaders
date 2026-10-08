; Developer 2: chef movement, lives, and timed player boost effects.
; All procedures require DS to address variables.inc. Drawing stays in display.asm.

; Procedure: initialize_player
; Purpose: Reset chef position, lives, and boost state for a new game.
; Input: None. Output: A centered chef with three lives and no boost.
; Modifies: None (all registers and flags preserved).
; Shared: player_x, player_y, player_lives, player_boost_frames, powerup_active.
initialize_player:
    mov byte [player_x], (SCREEN_WIDTH - PLAYER_WIDTH) / 2
    mov byte [player_y], SCREEN_HEIGHT - PLAYER_HEIGHT - 1
    mov byte [player_lives], 3
    mov word [player_boost_frames], 0
    mov byte [powerup_active], 0
    ret

; Procedure: update_player
; Purpose: Clamp the whole chef sprite to the playfield and tick its boost timer.
; Input: None. Output: Valid coordinates; expired boosts are disabled.
; Modifies: Flags only; all general-purpose registers preserved.
; Shared: player_x, player_y, player_boost_frames, powerup_active.
update_player:
    cmp byte [player_x], SCREEN_WIDTH - PLAYER_WIDTH
    jbe .row
    mov byte [player_x], SCREEN_WIDTH - PLAYER_WIDTH
.row:
    cmp byte [player_y], PLAYFIELD_TOP
    jae .bottom
    mov byte [player_y], PLAYFIELD_TOP
.bottom:
    cmp byte [player_y], SCREEN_HEIGHT - PLAYER_HEIGHT - 1
    jbe .timer
    mov byte [player_y], SCREEN_HEIGHT - PLAYER_HEIGHT - 1
.timer:
    cmp word [player_boost_frames], 0
    je .expired
    dec word [player_boost_frames]
    jnz .done
.expired:
    mov byte [powerup_active], 0
.done:
    ret

; Procedure: move_player_left
; Purpose: Move one column left, or two during an active boost, without underflow.
; Input: None. Output: player_x updated within the legal range.
; Modifies: AX, flags. Shared: player_x, player_boost_frames.
move_player_left:
    mov al, 1
    cmp word [player_boost_frames], 0
    je .move
    inc al
.move:
    cmp byte [player_x], SCREEN_WIDTH - PLAYER_WIDTH
    jbe .valid
    mov byte [player_x], SCREEN_WIDTH - PLAYER_WIDTH
.valid:
    cmp [player_x], al
    jb .edge
    sub [player_x], al
    ret
.edge:
    mov byte [player_x], 0
    ret

; Procedure: move_player_right
; Purpose: Move one column right, or two during a boost, without sprite overflow.
; Input: None. Output: player_x updated within the legal range.
; Modifies: AX, flags. Shared: player_x, player_boost_frames.
move_player_right:
    mov al, SCREEN_WIDTH - PLAYER_WIDTH - 1
    cmp word [player_boost_frames], 0
    je .normal
    dec al
    cmp [player_x], al
    ja .edge
    add byte [player_x], 2
    ret
.normal:
    cmp [player_x], al
    ja .edge
    inc byte [player_x]
    ret
.edge:
    mov byte [player_x], SCREEN_WIDTH - PLAYER_WIDTH
    ret

; Procedure: activate_player_powerup
; Purpose: Apply the document's temporary movement, damage, and fire-rate boost.
; Input: None (Developer 4 calls this when a pickup is caught).
; Output: Boost lasts BOOST_FRAMES ticks; repeated pickups refresh it.
; Modifies: None (all registers and flags preserved).
; Shared: game_state, player_boost_frames, powerup_active.
activate_player_powerup:
    pushf
    cmp byte [game_state], PLAYING
    jne .done
    mov word [player_boost_frames], BOOST_FRAMES
    mov byte [powerup_active], 1
.done:
    popf
    ret

; Procedure: player_hit
; Purpose: Lose one life during play; zero lives ends the game without underflow.
; Input: None. Output: player_lives and possibly game_state updated.
; Modifies: Flags only; all general-purpose registers preserved.
; Shared: game_state, player_lives.
player_hit:
    cmp byte [game_state], PLAYING
    jne .done
    cmp byte [player_lives], 0
    je .game_over
    dec byte [player_lives]
    jne .done
.game_over:
    mov byte [game_state], GAME_OVER
.done:
    ret
