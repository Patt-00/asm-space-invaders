; Run from the project directory:
; nasm -f bin tests/collision.asm -o COLLTEST.COM
; DOSBox-X: COLLTEST.COM > RESULT.TXT
; This harness needs no graphics mode or keyboard input.
bits 16
org 100h
jmp start
%include "variables.inc"
%include "modules/player.asm"
%include "modules/bullet.asm"
%include "modules/collision.asm"

%macro expect_byte 3
    cmp byte [%1], %2
    je %%ok
    mov dx, %%message
    jmp fail
%%message: db 'FAIL: ', %3, 13, 10, '$'
%%ok:
%endmacro

%macro expect_word 3
    cmp word [%1], %2
    je %%ok
    mov dx, %%message
    jmp fail
%%message: db 'FAIL: ', %3, 13, 10, '$'
%%ok:
%endmacro

%macro expect_reg 3
    cmp %1, %2
    je %%ok
    mov dx, %%message
    jmp fail
%%message: db 'FAIL: ', %3, 13, 10, '$'
%%ok:
%endmacro

; Check the public register contract on every path exercised below.
; Restore the harness's own registers after checking the sentinels.
%macro checked_call 1
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    mov bx, 1234h
    mov cx, 2345h
    mov dx, 3456h
    mov si, 4567h
    mov di, 5678h
    mov bp, 6789h
    mov [saved_sp], sp
    call %1
    expect_reg bx, 1234h, 'collision preserves BX'
    expect_reg cx, 2345h, 'collision preserves CX'
    expect_reg dx, 3456h, 'collision preserves DX'
    expect_reg si, 4567h, 'collision preserves SI'
    expect_reg di, 5678h, 'collision preserves DI'
    expect_reg bp, 6789h, 'collision preserves BP'
    cmp sp, [saved_sp]
    je %%balanced
    mov dx, stack_failed
    jmp fail
%%balanced:
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
%endmacro

start:
    mov ax, cs
    mov ds, ax
    mov es, ax
    cld

    ; Each row: projectile x/y and expected hit (all four corners and edges).
    mov si, bullet_cases
.bullet_case:
    call reset_state
    mov al, [si]
    mov [bullets_x + 1], al
    mov al, [si + 1]
    mov [bullets_y + 1], al
    mov byte [bullets_damage + 1], 2
    mov byte [bullets_active + 1], 1
    checked_call check_bullet_enemy
    cmp byte [si + 2], 0
    je .bullet_miss
    expect_byte enemy_health, 2, 'overlapping weapon applies its damage'
    expect_byte bullets_active + 1, 0, 'hit consumes the indexed slot'
    expect_byte bullets_damage + 1, 0, 'consumption clears shot damage'
    jmp .bullet_next
.bullet_miss:
    expect_byte enemy_health, 4, 'adjacent or separated weapon misses'
    expect_byte bullets_active + 1, 1, 'miss preserves projectile'
    expect_byte bullets_damage + 1, 2, 'miss preserves damage metadata'
.bullet_next:
    expect_byte enemy_alive, 1, 'nonlethal hits preserve enemy'
    expect_word score, 0, 'nonlethal hit or miss awards no score'
    expect_byte game_state, PLAYING, 'nonlethal hit or miss preserves play'
    add si, 3
    cmp si, bullet_cases_end
    jb .bullet_case

    ; Overlapping zero-damage and inactive shots cannot damage the enemy.
    call reset_state
    mov byte [bullets_x], 40
    mov byte [bullets_y], 30
    mov byte [bullets_damage], 3
    checked_call check_bullet_enemy
    expect_byte enemy_health, 4, 'inactive projectile does not damage'
    expect_byte bullets_damage, 3, 'inactive slot remains untouched'
    mov byte [bullets_damage], 0
    mov byte [bullets_active], 1
    checked_call check_bullet_enemy
    expect_byte enemy_health, 4, 'zero damage does not subtract health'
    expect_byte bullets_active, 0, 'zero-damage contact still consumes shot'

    ; Multiple slots can hit, but a lethal hit stops further consumption.
    call reset_state
    mov byte [bullets_x], 40
    mov byte [bullets_y], 30
    mov byte [bullets_damage], 1
    mov byte [bullets_active], 1
    mov byte [bullets_x + 1], 40
    mov byte [bullets_y + 1], 30
    mov byte [bullets_damage + 1], 255
    mov byte [bullets_active + 1], 1
    mov byte [bullets_x + 2], 40
    mov byte [bullets_y + 2], 30
    mov byte [bullets_damage + 2], 2
    mov byte [bullets_active + 2], 1
    checked_call check_bullet_enemy
    expect_byte bullets_active, 0, 'first slot applies nonlethal damage'
    expect_byte bullets_active + 1, 0, 'lethal slot is consumed'
    expect_byte bullets_active + 2, 1, 'slots after a kill remain active'
    expect_byte enemy_health, 0, 'excess damage saturates health at zero'
    expect_byte enemy_alive, 0, 'lethal hit removes enemy'
    expect_word score, 10, 'one kill awards ten points'
    expect_byte game_state, GAME_OVER, 'kill retains demo ending'
    checked_call check_collisions
    expect_word score, 10, 'repeated check cannot award a second score'
    expect_byte player_lives, 3, 'round ending skips remaining checks'

    ; Dead-enemy guards must also work while the game remains PLAYING.
    mov byte [game_state], PLAYING
    checked_call check_bullet_enemy
    checked_call check_enemy_player
    checked_call check_enemy_bottom
    expect_byte bullets_active + 2, 1, 'dead enemy cannot consume another shot'
    expect_word score, 10, 'dead enemy cannot award points'
    expect_byte player_lives, 3, 'dead enemy cannot damage chef'

    ; Each row: enemy x/y and expected chef contact.
    mov si, contact_cases
.contact_case:
    call reset_state
    mov al, [si]
    mov [enemy_x], al
    mov al, [si + 1]
    mov [enemy_y], al
    mov byte [bullets_active], 1
    mov byte [bullets_damage], 2
    checked_call check_enemy_player
    cmp byte [si + 2], 0
    je .contact_miss
    expect_byte player_lives, 2, 'chef overlap loses one life'
    expect_byte enemy_alive, 0, 'chef contact removes enemy'
    expect_byte enemy_health, 0, 'removed enemy has zero health'
    checked_call check_enemy_player
    expect_byte player_lives, 2, 'contact cannot damage twice'
    jmp .contact_next
.contact_miss:
    expect_byte player_lives, 3, 'touching or separated chef misses'
    expect_byte enemy_alive, 1, 'contact miss preserves enemy'
    expect_byte enemy_health, 4, 'contact miss preserves health'
.contact_next:
    expect_word score, 0, 'contact never awards points'
    expect_byte game_state, PLAYING, 'surviving contact preserves play'
    expect_byte bullets_active, 1, 'contact preserves unrelated projectile'
    expect_byte bullets_damage, 2, 'contact preserves projectile damage'
    add si, 3
    cmp si, contact_cases_end
    jb .contact_case

    ; Life exhaustion, including an already-zero life counter, never wraps.
    call reset_state
    mov byte [enemy_x], 60
    mov byte [enemy_y], 80
    mov byte [player_lives], 1
    checked_call check_enemy_player
    expect_byte player_lives, 0, 'last contact takes final life'
    expect_byte game_state, GAME_OVER, 'last contact ends play'
    checked_call check_enemy_player
    expect_byte player_lives, 0, 'repeated contact cannot underflow'
    call reset_state
    mov byte [enemy_x], 60
    mov byte [enemy_y], 80
    mov byte [player_lives], 0
    checked_call check_enemy_player
    expect_byte game_state, GAME_OVER, 'zero lives on contact ends play'

    ; Boundary detection uses the lowest occupied row, not enemy top row.
    call reset_state
    mov byte [enemy_y], SCREEN_HEIGHT - ENEMY_HEIGHT - 1
    checked_call check_enemy_bottom
    expect_byte enemy_alive, 1, 'enemy above last row has not breached'
    expect_byte player_lives, 3, 'no premature breach damage'
    inc byte [enemy_y]
    checked_call check_enemy_bottom
    expect_byte enemy_alive, 0, 'reaching last row removes enemy'
    expect_byte enemy_health, 0, 'breach clears enemy health'
    expect_byte player_lives, 2, 'breach deducts exactly one life'
    expect_byte game_state, PLAYING, 'surviving breach leaves play active'
    expect_word score, 0, 'breach awards no score'
    checked_call check_enemy_bottom
    expect_byte player_lives, 2, 'same breach cannot damage twice'
    call reset_state
    mov byte [enemy_y], 255
    mov byte [player_lives], 1
    checked_call check_enemy_bottom
    expect_byte player_lives, 0, 'overshooting breach cannot wrap its endpoint'
    expect_byte game_state, GAME_OVER, 'last breach ends play'

    ; Priority: lethal shot prevents contact and breach in the same frame.
    call reset_state
    mov byte [player_x], 40
    mov byte [player_y], SCREEN_HEIGHT - PLAYER_HEIGHT
    mov byte [enemy_y], SCREEN_HEIGHT - ENEMY_HEIGHT
    mov byte [bullets_x], 40
    mov byte [bullets_y], SCREEN_HEIGHT - ENEMY_HEIGHT
    mov byte [bullets_damage], 4
    mov byte [bullets_active], 1
    checked_call check_collisions
    expect_byte player_lives, 3, 'lethal shot wins over chef contact and breach'
    expect_word score, 10, 'dispatcher awards lethal-shot score'
    expect_byte game_state, GAME_OVER, 'dispatcher stops on demo completion'

    ; A nonlethal shot is applied before contact removes the surviving enemy.
    call reset_state
    mov byte [player_x], 40
    mov byte [player_y], SCREEN_HEIGHT - PLAYER_HEIGHT
    mov byte [enemy_y], SCREEN_HEIGHT - ENEMY_HEIGHT
    mov byte [bullets_x], 40
    mov byte [bullets_y], SCREEN_HEIGHT - ENEMY_HEIGHT
    mov byte [bullets_damage], 1
    mov byte [bullets_active], 1
    checked_call check_collisions
    expect_byte bullets_active, 0, 'projectile collision precedes contact'
    expect_byte player_lives, 2, 'contact plus breach loses only one life'
    expect_byte enemy_alive, 0, 'contact removes surviving enemy'
    expect_word score, 0, 'nonlethal hit plus contact awards no score'
    checked_call check_collisions
    expect_byte player_lives, 2, 'repeated dispatcher cannot double damage'

    ; An unaligned enemy still causes a breach through the dispatcher.
    call reset_state
    mov byte [enemy_y], SCREEN_HEIGHT - ENEMY_HEIGHT
    checked_call check_collisions
    expect_byte player_lives, 2, 'dispatcher checks breaches after contact misses'

    ; Byte-limit coordinates exercise word arithmetic on both axes.
    call reset_state
    mov byte [enemy_x], 254
    mov byte [enemy_y], 254
    mov byte [bullets_x], 255
    mov byte [bullets_y], 255
    mov byte [bullets_active], 1
    mov byte [bullets_damage], 1
    checked_call check_bullet_enemy
    expect_byte enemy_health, 3, 'weapon endpoints above 255 still overlap'
    call reset_state
    mov byte [player_x], 254
    mov byte [player_y], 254
    mov byte [enemy_x], 255
    mov byte [enemy_y], 255
    checked_call check_enemy_player
    expect_byte player_lives, 2, 'chef endpoints above 255 still overlap'
    call reset_state
    mov byte [enemy_x], 1
    mov byte [enemy_y], 1
    mov byte [bullets_x], 255
    mov byte [bullets_y], 255
    mov byte [bullets_active], 1
    mov byte [bullets_damage], 1
    checked_call check_bullet_enemy
    expect_byte enemy_health, 4, 'large endpoints cannot wrap into low coordinates'

    ; Each public entry point must leave all shared state unchanged outside play.
    mov si, inactive_states
.state_case:
    call reset_state
    mov al, [si]
    mov [game_state], al
    mov byte [enemy_x], 60
    mov byte [enemy_y], SCREEN_HEIGHT - ENEMY_HEIGHT
    mov byte [player_y], SCREEN_HEIGHT - PLAYER_HEIGHT
    mov byte [bullets_x], 60
    mov byte [bullets_y], SCREEN_HEIGHT - ENEMY_HEIGHT
    mov byte [bullets_active], 1
    mov byte [bullets_damage], 255
    checked_call check_collisions
    checked_call check_bullet_enemy
    checked_call check_enemy_player
    checked_call check_enemy_bottom
    expect_byte enemy_alive, 1, 'inactive game state preserves enemy'
    expect_byte enemy_health, 4, 'inactive game state preserves health'
    expect_byte bullets_active, 1, 'inactive game state preserves projectile'
    expect_byte bullets_damage, 255, 'inactive game state preserves damage'
    expect_byte player_lives, 3, 'inactive game state preserves lives'
    expect_word score, 0, 'inactive game state preserves score'
    mov al, [si]
    cmp [game_state], al
    je .state_next
    mov dx, state_failed
    jmp fail
.state_next:
    inc si
    cmp si, inactive_states_end
    jb .state_case

    mov dx, passed
    mov ah, 09h
    int 21h
    mov ax, 4C00h
    int 21h

reset_state:
    call initialize_player
    call initialize_bullets
    mov byte [player_x], 60
    mov byte [player_y], 80
    mov byte [enemy_x], 40
    mov byte [enemy_y], 30
    mov byte [enemy_alive], 1
    mov byte [enemy_health], 4
    mov word [score], 0
    mov byte [game_state], PLAYING
    ret

fail:
    mov ah, 09h
    int 21h
    mov ax, 4C01h
    int 21h

bullet_cases:
    db 40 - WEAPON_WIDTH + 1, 30 - WEAPON_HEIGHT + 1, 1
    db 40 + ENEMY_WIDTH - 1, 30 - WEAPON_HEIGHT + 1, 1
    db 40 - WEAPON_WIDTH + 1, 30 + ENEMY_HEIGHT - 1, 1
    db 40 + ENEMY_WIDTH - 1, 30 + ENEMY_HEIGHT - 1, 1
    db 40, 30, 1
    db 40 - WEAPON_WIDTH, 30, 0
    db 40 + ENEMY_WIDTH, 30, 0
    db 40, 30 - WEAPON_HEIGHT, 0
    db 40, 30 + ENEMY_HEIGHT, 0
    db 40 - WEAPON_WIDTH - 1, 30, 0
    db 40 + ENEMY_WIDTH + 1, 30, 0
    db 40, 30 - WEAPON_HEIGHT - 1, 0
    db 40, 30 + ENEMY_HEIGHT + 1, 0
bullet_cases_end:
contact_cases:
    db 60 - ENEMY_WIDTH + 1, 80 - ENEMY_HEIGHT + 1, 1
    db 60 + PLAYER_WIDTH - 1, 80 - ENEMY_HEIGHT + 1, 1
    db 60 - ENEMY_WIDTH + 1, 80 + PLAYER_HEIGHT - 1, 1
    db 60 + PLAYER_WIDTH - 1, 80 + PLAYER_HEIGHT - 1, 1
    db 60, 80, 1
    db 60 - ENEMY_WIDTH, 80, 0
    db 60 + PLAYER_WIDTH, 80, 0
    db 60, 80 - ENEMY_HEIGHT, 0
    db 60, 80 + PLAYER_HEIGHT, 0
    db 60 - ENEMY_WIDTH - 1, 80, 0
    db 60 + PLAYER_WIDTH + 1, 80, 0
    db 60, 80 - ENEMY_HEIGHT - 1, 0
    db 60, 80 + PLAYER_HEIGHT + 1, 0
contact_cases_end:
inactive_states: db MENU, GAME_OVER, QUIT
inactive_states_end:
saved_sp dw 0
stack_failed db 'FAIL: collision leaves a balanced stack', 13, 10, '$'
state_failed db 'FAIL: collision preserves inactive game state', 13, 10, '$'
passed db 'PASS: collision geometry, damage, priority, guards and registers', 13, 10, '$'
