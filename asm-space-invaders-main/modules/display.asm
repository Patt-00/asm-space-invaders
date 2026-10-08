; Display-owned text rendering: compose in RAM, then copy a complete VGA frame.

%include "assets/player_art.inc"
%include "assets/enemy_art.inc"
%include "assets/bullet_art.inc"

hud_score_text db 'SCORE: ', 0
hud_lives_text db 'LIVES: ', 0
hud_controls_text db 'SPACE: Cleaver  X: Pin  A/D: Move  ESC: Quit', 0
hud_controls_end:
hud_ready_text db 'READY', 0
hud_wait_text db 'WAIT ', 0
hud_enemy_text db 'TARGET HP: ', 0
hud_boost_text db 'BOOST', 0

; -------------------------------------------------
; Procedure: initialize_display
; Purpose: Extend DOSBox-X's 132x60 SVGA mode to 120 native 8x8 rows.
; Input: DS=shared segment. Output: CF=0 ready; CF=1 unsupported mode.
; Modifies: Flags only; general-purpose registers and ES preserved.
; Shared: render_buffer, render_cursor; BIOS geometry and VGA timing.
; -------------------------------------------------
initialize_display:
    push ax
    push bx
    push cx
    push dx
    push si
    push es
    mov ax, 4F02h
    mov bx, 010Ch             ; Start with SVGA 132 columns and the 8x8 font.
    int 10h
    cmp ax, 004Fh
    jne .unsupported
    mov ax, 40h
    mov es, ax
    cmp word [es:4Ah], SCREEN_WIDTH
    jne .unsupported

    ; Unlock the VGA timing registers before extending the vertical raster.
    mov dx, 03D4h
    mov al, 11h
    out dx, al
    inc dx
    in al, dx
    and al, 7Fh
    out dx, al
    mov dx, 03D4h
    mov si, tall_display_timing
    mov cx, (tall_display_timing_end - tall_display_timing) / 2
    cld
.timing:
    lodsw                    ; AL=CRTC register, AH=value; OUT writes both ports.
    out dx, ax
    loop .timing
    mov byte [es:84h], SCREEN_HEIGHT - 1
    mov word [es:4Ch], 8000h  ; One complete frame uses almost 32 KiB.
    mov ah, 01h
    mov cx, 2000h
    int 10h                  ; Hide the text cursor.
    call clear_screen
    call present_frame
    ; Allow the emulator to resize before the first nonblank menu is drawn.
    mov ah, 86h
    mov cx, 3
    mov dx, 0D40h             ; 200,000 microseconds, only during mode setup.
    int 15h
    clc
    jmp .restore
.unsupported:
    stc
.restore:
    pop es
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; 960 visible scanlines = 120 rows * 8 pixels. 1023 total scanlines
; leave room for blanking/retrace. Overflow bits encode scanlines 8 and 9.
; Max-scanline retains eight-pixel glyphs and disables double scanning.
tall_display_timing:
    dw 0FD06h                ; Vertical total = 1023 (register stores total-2).
    dw 0FF07h                ; Vertical overflow bits; line compare > raster.
    dw 06709h                ; Eight glyph scanlines; blank/line-compare overflow.
    dw 0BF12h                ; Last visible scanline = 959 (03BFh).
    dw 0D410h                ; Vertical retrace starts at scanline 980.
    dw 02811h                ; Retrace ends at 984; timing registers unlocked.
    dw 0C015h                ; Vertical blank starts at scanline 960.
    dw 0FF16h                ; Vertical blank ends at the end of the raster.
    dw 0FF18h                ; Line compare = 1023, avoiding a split screen.
tall_display_timing_end:

; -------------------------------------------------
; Procedure: clear_screen
; Purpose: Clear the off-screen text frame, avoiding visible partial frames.
; Input: None. Output: White-on-black blank frame; drawing cursor reset.
; Modifies: Flags only; general-purpose registers and ES preserved.
; Shared: render_buffer, render_cursor.
; -------------------------------------------------
clear_screen:
    push ax
    push cx
    push di
    push es
    push ds
    pop es
    mov di, render_buffer
    mov ax, 0720h
    mov cx, SCREEN_WIDTH * SCREEN_HEIGHT
    cld
    rep stosw
    mov word [render_cursor], 0
    pop es
    pop di
    pop cx
    pop ax
    ret

; -------------------------------------------------
; Procedure: set_cursor
; Purpose: Set the off-screen text drawing position.
; Input: DH=row, DL=column. Output: render_cursor byte offset updated.
; Modifies: Flags only; general-purpose registers preserved.
; Shared: render_cursor.
; -------------------------------------------------
set_cursor:
    push ax
    push bx
    push dx
    xor ax, ax
    mov al, dh
    mov bx, SCREEN_WIDTH
    mul bx
    pop dx
    push dx
    xor dh, dh
    add ax, dx
    shl ax, 1
    mov [render_cursor], ax
    pop dx
    pop bx
    pop ax
    ret

; -------------------------------------------------
; Procedure: print_char
; Purpose: Write one white-on-black character at the off-screen cursor.
; Input: AL=character. Output: Character written; cursor advances one cell.
; Modifies: Flags only; general-purpose registers preserved.
; Shared: render_buffer, render_cursor.
; -------------------------------------------------
print_char:
    push ax
    push di
    mov di, [render_cursor]
    cmp di, SCREEN_WIDTH * SCREEN_HEIGHT * 2
    jae .done
    mov ah, 07h
    mov [render_buffer + di], ax
    add word [render_cursor], 2
.done:
    pop di
    pop ax
    ret

; -------------------------------------------------
; Procedure: print_string
; Purpose: Write a zero-terminated string into the off-screen text frame.
; Input: DS:SI=string. Output: Text written; drawing cursor advanced.
; Modifies: AX, SI, flags. Shared: render_buffer, render_cursor.
; -------------------------------------------------
print_string:
    cld
    lodsb
    or al, al
    jz .done
    call print_char
    jmp print_string
.done:
    ret

; -------------------------------------------------
; Procedure: draw_sprite
; Purpose: Copy each original ASCII character into the enlarged text field.
; Input: DS:SI=art, CL=width, CH=height, DH=row, DL=column, BL=color.
; Output: Exact sprite rows and spacing, with no resampling or compression.
; Modifies: Flags only; all general-purpose registers preserved.
; Shared: render_buffer.
; -------------------------------------------------
draw_sprite:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    xor ax, ax
    mov al, dh
    mov di, SCREEN_WIDTH
    push dx
    mul di
    pop dx
    xor dh, dh
    add ax, dx
    shl ax, 1
    mov di, ax
    mov bp, cx
    shr bp, 8
    xor ch, ch
    jcxz .done
    test bp, bp
    jz .done
    cld
.row:
    push cx
.cell:
    cmp di, SCREEN_WIDTH * SCREEN_HEIGHT * 2
    jae .row_done
    lodsb
    mov ah, bl
    mov [render_buffer + di], ax
    add di, 2
    loop .cell
.row_done:
    pop cx
    cmp di, SCREEN_WIDTH * SCREEN_HEIGHT * 2
    jae .done
    add di, SCREEN_WIDTH * 2
    sub di, cx
    sub di, cx
    dec bp
    jnz .row
.done:
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; -------------------------------------------------
; Procedure: draw_weapon_sprite
; Purpose: Reduce unchanged 12x16 weapon art uniformly to 6x8 screen cells.
; Input: DS:SI=source art, DH=row, DL=column, BL=color.
; Output: Each 2x2 block keeps its first nonblank source character.
; Modifies: Flags only; all general-purpose registers preserved.
; Shared: render_buffer. Chef rendering continues to use draw_sprite.
; -------------------------------------------------
draw_weapon_sprite:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    xor ax, ax
    mov al, dh
    mov di, SCREEN_WIDTH
    push dx
    mul di
    pop dx
    xor dh, dh
    add ax, dx
    shl ax, 1
    mov di, ax
    mov bp, WEAPON_HEIGHT
.row:
    mov cx, WEAPON_WIDTH
.cell:
    cmp di, SCREEN_WIDTH * SCREEN_HEIGHT * 2
    jae .done
    mov al, [si]
    cmp al, ' '
    jne .paint
    mov al, [si + 1]
    cmp al, ' '
    jne .paint
    mov al, [si + SOURCE_ART_WIDTH]
    cmp al, ' '
    jne .paint
    mov al, [si + SOURCE_ART_WIDTH + 1]
.paint:
    mov ah, bl
    mov [render_buffer + di], ax
    add di, 2
    add si, WEAPON_SCALE
    loop .cell
    add si, SOURCE_ART_WIDTH ; Skip the other row of each source block.
    add di, (SCREEN_WIDTH - WEAPON_WIDTH) * 2
    dec bp
    jnz .row
.done:
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; -------------------------------------------------
; Procedure: present_frame
; Purpose: Copy the composed frame to VGA text memory in one pass.
; Input: None. Output: Complete 132x120 frame visible.
; Modifies: Flags only; general-purpose registers and ES preserved.
; Shared: render_buffer.
; -------------------------------------------------
present_frame:
    push ax
    push cx
    push si
    push di
    push es
    mov ax, 0B800h
    mov es, ax
    xor di, di
    mov si, render_buffer
    mov cx, SCREEN_WIDTH * SCREEN_HEIGHT
    cld
    rep movsw
    pop es
    pop di
    pop si
    pop cx
    pop ax
    ret

; -------------------------------------------------
; Procedure: draw_player
; Purpose: Render all original chef characters at their native size from shared coordinates.
; Input: None. Output: Chef displayed in white.
; Modifies: BX, CX, DX, SI; flags. Shared: player_x, player_y.
; -------------------------------------------------
draw_player:
    mov dh, [player_y]
    mov dl, [player_x]
    mov si, player_art
    mov cl, PLAYER_WIDTH
    mov ch, PLAYER_HEIGHT
    mov bl, 0Fh
    call draw_sprite
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
; Purpose: Draw every active weapon using the unchanged art at half size.
; Input: None. Output: Primary shots cyan, secondary yellow, boosted shots red.
; Modifies: AX, BX, CX, DX, SI; flags (DI preserved).
; Shared: bullets_x/y/active/kind/damage.
; -------------------------------------------------
draw_bullet:
    push di
    xor di, di
.loop:
    cmp byte [bullets_active + di], 1
    jne .next
    mov si, cleaver_art
    mov bl, 0Bh
    cmp byte [bullets_kind + di], ROLLING_PIN
    jne .color
    mov si, rolling_pin_art
    mov bl, 0Eh
.color:
    mov al, [bullets_kind + di]
    inc al
    cmp [bullets_damage + di], al
    jbe .draw
    mov bl, 0Ch
.draw:
    mov dh, [bullets_y + di]
    mov dl, [bullets_x + di]
    call draw_weapon_sprite
.next:
    inc di
    cmp di, MAX_BULLETS
    jb .loop
    pop di
    ret

; -------------------------------------------------
; Procedure: draw_hud
; Purpose: Draw score and lives across the top row.
; Input: None
; Output: HUD text is displayed.
; Modifies: AX, BX, DX, SI
; Shared variables used: score, player_lives, player_boost_frames, enemy_health, fire_cooldown
; -------------------------------------------------
draw_hud:
    mov dh, 0
    mov dl, 12
    call set_cursor
    mov si, hud_ready_text
    cmp byte [fire_cooldown], 0
    je .attack_status
    mov si, hud_wait_text
.attack_status:
    call print_string
    mov dh, SCREEN_HEIGHT - 1
    mov dl, (SCREEN_WIDTH - (hud_controls_end - hud_controls_text - 1)) / 2
    call set_cursor
    mov si, hud_controls_text
    call print_string
    mov dh, 0
    mov dl, (SCREEN_WIDTH - 12) / 2
    call set_cursor
    mov si, hud_enemy_text
    call print_string
    mov ax, 0
    mov al, [enemy_health]
    call print_number_0_99
    cmp word [player_boost_frames], 0
    je .stats
    mov dh, 0
    mov dl, SCREEN_WIDTH - 6
    call set_cursor
    mov si, hud_boost_text
    call print_string
.stats:
    mov dh, 0
    mov dl, 1
    call set_cursor
    mov si, hud_score_text
    call print_string
    mov ax, [score]
    call print_number_0_99
    mov dh, 0
    mov dl, SCREEN_WIDTH - 15
    call set_cursor
    mov si, hud_lives_text
    call print_string
    mov al, [player_lives]
    add al, '0'
    call print_char
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
    call print_char
.ones:
    mov al, dl
    add al, '0'
    call print_char
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
    call present_frame
    ret
