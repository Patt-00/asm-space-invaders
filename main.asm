; Space Invaders architecture prototype for NASM, DOS, and 80x25 text mode.
; Build with: nasm -f bin main.asm -o INVADERS.COM

bits 16
org 100h

jmp start

%include "variables.inc"

start:
    mov ax, cs
    mov ds, ax
    mov es, ax
    call initialize_program

main_menu:
    call show_main_menu
    call wait_for_menu_input       ; AL = 1 for play, 2 for quit.
    cmp al, 2
    je quit_program

new_game:
    call initialize_game

game_loop:
    call read_input
    call update_player
    call update_bullets
    call update_enemies
    call check_collisions
    call update_features
    call draw_game

    cmp byte [game_state], PLAYING
    je game_loop
    cmp byte [game_state], GAME_OVER
    jne quit_program

    call show_game_over
    call wait_for_menu_input       ; R/Space starts over; Q/Esc quits.
    cmp al, 1
    je new_game

quit_program:
    mov ax, 4C00h
    int 21h

; -------------------------------------------------
; Procedure: initialize_program
; Purpose: Select the standard DOS text mode.
; Input: None
; Output: Screen is in 80x25 text mode.
; Modifies: AX
; Shared variables used: None
; -------------------------------------------------
initialize_program:
    mov ax, 0003h
    int 10h
    ret

; -------------------------------------------------
; Procedure: initialize_game
; Purpose: Reset all shared state for a new game.
; Input: None
; Output: A fresh playable prototype state.
; Modifies: AX
; Shared variables used: All game state variables
; -------------------------------------------------
initialize_game:
    mov byte [player_x], 38
    mov byte [player_y], 22
    mov byte [player_lives], 3
    mov byte [bullet_active], 0
    mov byte [enemy_x], 37
    mov byte [enemy_y], 4
    mov byte [enemy_alive], 1
    mov word [score], 0
    mov byte [current_wave], 1
    mov byte [shield_active], 0
    mov byte [powerup_active], 0
    mov byte [game_state], PLAYING
    call initialize_enemies
    ret

; -------------------------------------------------
; Procedure: read_input
; Purpose: Read one pending keyboard command without pausing the game loop.
; Input: None
; Output: May move, fire, or request quit.
; Modifies: AX
; Shared variables used: game_state
; -------------------------------------------------
read_input:
    mov ah, 01h
    int 16h
    jz .done
    mov ah, 00h
    int 16h

    cmp al, 1Bh                 ; Escape
    je .quit
    cmp al, 'a'
    je .left
    cmp al, 'A'
    je .left
    cmp al, 'd'
    je .right
    cmp al, 'D'
    je .right
    cmp al, ' '
    je .fire
    cmp ah, 4Bh                 ; Left arrow scan code
    je .left
    cmp ah, 4Dh                 ; Right arrow scan code
    je .right
    jmp .done
.left:
    call move_player_left
    jmp .done
.right:
    call move_player_right
    jmp .done
.fire:
    call fire_bullet
    jmp .done
.quit:
    mov byte [game_state], QUIT
.done:
    ret

%include "modules/player.asm"
%include "modules/bullet.asm"
%include "modules/enemy.asm"
%include "modules/collision.asm"
%include "modules/display.asm"
%include "modules/menu.asm"
%include "modules/features.asm"
