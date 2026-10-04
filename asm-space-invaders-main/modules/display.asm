; All text-mode drawing is isolated here.  Gameplay modules must not print.

%include "assets/player_art.inc"
%include "assets/enemy_art.inc"
%include "assets/bullet_art.inc"

hud_score_text db 'SCORE: ', 0
hud_lives_text db 'LIVES: ', 0

; -------------------------------------------------
; Procedure: clear_screen
; Purpose: Clear the 80x25 text display.
; Input: None
; Output: Screen contains blank white-on-black cells.
; Modifies: AX, BX, CX, DX
; Shared variables used: None
; -------------------------------------------------
clear_screen:
    mov ax, 0600h
    mov bh, 07h
    mov cx, 0000h
    mov dx, 184Fh
    int 10h
    ret

; -------------------------------------------------
; Procedure: set_cursor
; Purpose: Position the text cursor.
; Input: DH = row (0-24), DL = column (0-79)
; Output: Cursor is positioned.
; Modifies: AX, BX
; Shared variables used: None
; -------------------------------------------------
set_cursor:
    mov ah, 02h
    mov bh, 0
    int 10h
    ret

; -------------------------------------------------
; Procedure: print_string
; Purpose: Print a zero-terminated string at the current cursor position.
; Input: DS:SI = string address
; Output: Characters are displayed.
; Modifies: AX, SI
; Shared variables used: None
; -------------------------------------------------
print_string:
    lodsb
    or al, al
    jz .done
    mov ah, 0Eh
    mov bh, 0
    mov bl, 07h
    int 10h
    jmp print_string
.done:
    ret

; -------------------------------------------------
; Procedure: draw_player
; Purpose: Draw the player ASCII sprite from shared coordinates.
; Input: None
; Output: Player art is displayed.
; Modifies: AX, DX, SI
; Shared variables used: player_x, player_y
; -------------------------------------------------
draw_player:
    mov dh, [player_y]
    mov dl, [player_x]
    call set_cursor
    mov si, player_art_line1
    call print_string
    inc dh
    mov dl, [player_x]
    call set_cursor
    mov si, player_art_line2
    call print_string
    ret

; -------------------------------------------------
; Procedure: draw_enemy
; Purpose: Draw the living prototype enemy ASCII sprite.
; Input: None
; Output: Enemy art is displayed if enemy_alive is 1.
; Modifies: AX, DX, SI
; Shared variables used: enemy_x, enemy_y, enemy_alive
; -------------------------------------------------
draw_enemy:
    cmp byte [enemy_alive], 1
    jne .done
    mov dh, [enemy_y]
    mov dl, [enemy_x]
    call set_cursor
    mov si, enemy_art_line1
    call print_string
    inc dh
    mov dl, [enemy_x]
    call set_cursor
    mov si, enemy_art_line2
    call print_string
    inc dh
    mov dl, [enemy_x]
    call set_cursor
    mov si, enemy_art_line3
    call print_string
.done:
    ret

; -------------------------------------------------
; Procedure: draw_bullet
; Purpose: Draw the one active player bullet.
; Input: None
; Output: Bullet art is displayed when active.
; Modifies: AX, DX, SI
; Shared variables used: bullet_x, bullet_y, bullet_active
; -------------------------------------------------
draw_bullet:
    cmp byte [bullet_active], 1
    jne .done
    mov dh, [bullet_y]
    mov dl, [bullet_x]
    call set_cursor
    mov si, bullet_art
    call print_string
.done:
    ret

; -------------------------------------------------
; Procedure: draw_hud
; Purpose: Draw score and lives across the top row.
; Input: None
; Output: HUD text is displayed.
; Modifies: AX, BX, DX, SI
; Shared variables used: score, player_lives
; -------------------------------------------------
draw_hud:
    mov dh, 0
    mov dl, 1
    call set_cursor
    mov si, hud_score_text
    call print_string
    mov ax, [score]
    call print_number_0_99
    mov dh, 0
    mov dl, 65
    call set_cursor
    mov si, hud_lives_text
    call print_string
    mov al, [player_lives]
    add al, '0'
    mov ah, 0Eh
    int 10h
    ret

; -------------------------------------------------
; Procedure: print_number_0_99
; Purpose: Print an unsigned score from 0 through 99.
; Input: AX = number to print
; Output: Decimal number is displayed at the current cursor.
; Modifies: AX, BX, DX
; Shared variables used: None
; -------------------------------------------------
print_number_0_99:
    mov bl, 10
    div bl                      ; AL = tens digit, AH = ones digit.
    mov dl, ah
    or al, al
    jz .ones
    add al, '0'
    mov ah, 0Eh
    int 10h
.ones:
    mov al, dl
    add al, '0'
    mov ah, 0Eh
    int 10h
    ret

; -------------------------------------------------
; Procedure: draw_game
; Purpose: Render a complete gameplay frame from shared state.
; Input: None
; Output: Screen displays the current game state.
; Modifies: AX, BX, CX, DX, SI
; Shared variables used: player, bullet, enemy, score, and lives variables
; -------------------------------------------------
draw_game:
    call clear_screen
    call draw_hud
    call draw_enemy
    call draw_bullet
    call draw_player
    ret
