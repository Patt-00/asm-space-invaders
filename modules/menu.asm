; Menu and game-over screens.  The input routine returns a simple choice to main.asm.

%include "assets/title_art.inc"
%include "assets/gameover_art.inc"

menu_play_text db '1. PLAY', 0
menu_quit_text db '2. QUIT', 0
menu_hint_text db 'Press 1, P, or SPACE to play.  Press 2, Q, or ESC to quit.', 0
over_hint_text db 'Press R or SPACE to restart.  Press Q or ESC to quit.', 0

; -------------------------------------------------
; Procedure: show_main_menu
; Purpose: Draw the initial game menu.
; Input: None
; Output: Main menu text is displayed.
; Modifies: AX, BX, CX, DX, SI
; Shared variables used: None
; -------------------------------------------------
show_main_menu:
    call clear_screen
    mov dh, 5
    mov dl, 28
    call set_cursor
    mov si, title_art_line1
    call print_string
    mov dh, 7
    mov dl, 35
    call set_cursor
    mov si, menu_play_text
    call print_string
    mov dh, 8
    mov dl, 35
    call set_cursor
    mov si, menu_quit_text
    call print_string
    mov dh, 12
    mov dl, 9
    call set_cursor
    mov si, menu_hint_text
    call print_string
    ret

; -------------------------------------------------
; Procedure: show_game_over
; Purpose: Draw the game-over screen after the prototype round ends.
; Input: None
; Output: Game-over text is displayed.
; Modifies: AX, BX, CX, DX, SI
; Shared variables used: score
; -------------------------------------------------
show_game_over:
    call clear_screen
    mov dh, 7
    mov dl, 27
    call set_cursor
    mov si, gameover_art_line1
    call print_string
    mov dh, 12
    mov dl, 11
    call set_cursor
    mov si, over_hint_text
    call print_string
    ret

; -------------------------------------------------
; Procedure: wait_for_menu_input
; Purpose: Wait for a menu/restart choice.
; Input: None
; Output: AL = 1 to play/restart, AL = 2 to quit.
; Modifies: AX
; Shared variables used: None
; -------------------------------------------------
wait_for_menu_input:
    mov ah, 00h
    int 16h
    cmp al, '1'
    je .play
    cmp al, 'p'
    je .play
    cmp al, 'P'
    je .play
    cmp al, 'r'
    je .play
    cmp al, 'R'
    je .play
    cmp al, ' '
    je .play
    cmp al, '2'
    je .quit
    cmp al, 'q'
    je .quit
    cmp al, 'Q'
    je .quit
    cmp al, 1Bh
    je .quit
    jmp wait_for_menu_input
.play:
    mov al, 1
    ret
.quit:
    mov al, 2
    ret
