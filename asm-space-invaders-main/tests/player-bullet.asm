; nasm -f bin tests/player-bullet.asm -o PBTEST.COM
; DOSBox: PBTEST.COM > RESULT.TXT
bits 16
org 100h
jmp start
%include "variables.inc"
%include "modules/player.asm"
%include "modules/bullet.asm"
%include "modules/collision.asm"
%include "modules/display.asm"
%include "assets/source_art.inc"

%macro expect 3
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

start:
    mov ax, cs
    mov ds, ax
    call initialize_display
    jc video_failed
    mov ax, 40h
    mov es, ax
    mov ax, [es:4Ah]
    expect_reg ax, SCREEN_WIDTH, 'BIOS reports the full battlefield width'
    mov al, [es:84h]
    expect_reg al, SCREEN_HEIGHT - 1, 'BIOS reports 120 rows'
    mov ax, [es:4Ch]
    expect_reg ax, 8000h, 'BIOS page includes the full 120-row frame'
    push ds
    pop es
    call initialize_player
    call initialize_bullets
    mov byte [game_state], PLAYING
    expect player_x, (SCREEN_WIDTH - PLAYER_WIDTH) / 2, 'centered original chef'
    expect player_y, SCREEN_HEIGHT - PLAYER_HEIGHT - 1, 'full chef fits above footer'
    expect player_lives, 3, 'three initial lives'
    expect_word player_boost_frames, 0, 'no initial boost'
    expect fire_cooldown, 0, 'no initial cooldown'
    mov byte [player_x], 0
    call move_player_left
    expect player_x, 0, 'left boundary'
    call move_player_right
    expect player_x, 1, 'normal right movement'
    call move_player_left
    expect player_x, 0, 'normal left movement'
    mov byte [player_x], SCREEN_WIDTH - PLAYER_WIDTH
    call move_player_right
    expect player_x, SCREEN_WIDTH - PLAYER_WIDTH, 'right boundary includes full sprite'
    mov byte [player_x], 255
    call move_player_left
    expect player_x, SCREEN_WIDTH - PLAYER_WIDTH - 1, 'repair invalid position before left movement'
    mov byte [player_x], 255
    call move_player_right
    expect player_x, SCREEN_WIDTH - PLAYER_WIDTH, 'repair invalid position before right movement'
    mov byte [player_x], 255
    mov byte [player_y], 255
    call update_player
    expect player_x, SCREEN_WIDTH - PLAYER_WIDTH, 'clamp invalid column'
    expect player_y, SCREEN_HEIGHT - PLAYER_HEIGHT - 1, 'clamp invalid row'
    mov byte [player_y], 0
    call update_player
    expect player_y, 1, 'chef never overlaps HUD'
    call initialize_player
    call player_hit
    expect player_lives, 2, 'damage subtracts one life'
    expect game_state, PLAYING, 'survive a hit'
    call player_hit
    call player_hit
    expect player_lives, 0, 'last hit reaches zero'
    expect game_state, GAME_OVER, 'last hit ends play'
    call player_hit
    expect player_lives, 0, 'no life underflow'
    mov byte [game_state], PLAYING
    call player_hit
    expect game_state, GAME_OVER, 'already zero lives ends play'
    mov byte [game_state], QUIT
    mov byte [player_lives], 1
    call player_hit
    expect player_lives, 1, 'no damage after quit'
    expect game_state, QUIT, 'damage preserves quit'
    mov byte [game_state], MENU
    call fire_bullet
    call fire_secondary
    call activate_player_powerup
    expect bullet_active, 0, 'menu blocks both weapons'
    expect powerup_active, 0, 'menu blocks boost activation'
    mov byte [game_state], PLAYING
    call initialize_player
    call fire_bullet
    expect bullet_active, 1, 'primary allocates first slot'
    expect bullet_x, (SCREEN_WIDTH - WEAPON_WIDTH) / 2, 'cleaver centered relative to chef'
    expect bullet_y, SCREEN_HEIGHT - PLAYER_HEIGHT - WEAPON_HEIGHT - 1, 'smaller weapon starts above chef'
    expect bullets_kind, CLEAVER, 'primary weapon kind'
    expect bullets_damage, 1, 'normal cleaver damage'
    expect fire_cooldown, NORMAL_COOLDOWN, 'normal firing cooldown'
    call fire_secondary
    expect bullets_active + 1, 0, 'cooldown blocks next shot'
    mov byte [player_x], 0
    call update_bullets
    expect bullet_x, (SCREEN_WIDTH - WEAPON_WIDTH) / 2, 'projectile independent of moving chef'
    expect bullet_y, SCREEN_HEIGHT - PLAYER_HEIGHT - WEAPON_HEIGHT - 1 - BULLET_SPEED, 'projectile moves three rows per frame'
    expect fire_cooldown, NORMAL_COOLDOWN - 1, 'cooldown ticks each frame'
    mov cx, NORMAL_COOLDOWN - 1
    call tick_bullets
    expect fire_cooldown, 0, 'cooldown expires after the full normal interval'
    call fire_secondary
    expect bullets_active + 1, 1, 'secondary allocates next slot'
    expect bullets_kind + 1, ROLLING_PIN, 'secondary kind'
    expect bullets_damage + 1, 2, 'secondary damage'
    expect fire_cooldown, SECONDARY_COOLDOWN, 'stronger weapon fires more slowly'
    expect bullets_x + 1, (PLAYER_WIDTH - WEAPON_WIDTH) / 2, 'left-edge shot fits screen'
    expect bullet_x, (SCREEN_WIDTH - WEAPON_WIDTH) / 2, 'existing shot not overwritten'
    mov byte [fire_cooldown], 0
    call fire_bullet
    expect bullets_active + 2, 1, 'third slot allocated'
    mov byte [fire_cooldown], 0
    call fire_secondary
    expect bullets_kind + 2, CLEAVER, 'full pool does not overwrite a slot'
    expect fire_cooldown, 0, 'full pool does not charge cooldown'
    mov si, 1
    call remove_bullet_slot
    expect bullets_active + 1, 0, 'remove selected slot'
    expect bullets_damage + 1, 0, 'removal clears damage'
    expect bullet_active, 1, 'other slots survive removal'
    mov si, MAX_BULLETS
    call remove_bullet_slot
    expect bullets_kind, CLEAVER, 'invalid removal cannot touch adjacent memory'
    mov byte [player_x], SCREEN_WIDTH - PLAYER_WIDTH
    call fire_secondary
    expect bullets_x + 1, SCREEN_WIDTH - PLAYER_WIDTH + (PLAYER_WIDTH - WEAPON_WIDTH) / 2, 'right-edge smaller weapon stays centered on chef'
    call initialize_bullets
    expect bullet_active, 0, 'restart clears first slot'
    expect bullets_active + 1, 0, 'restart clears second slot'
    expect bullets_active + 2, 0, 'restart clears third slot'
    expect bullets_damage + 2, 0, 'restart clears damage metadata'
    expect fire_cooldown, 0, 'restart clears cooldown'

    mov byte [player_y], 0
    call fire_bullet
    expect bullet_active, 0, 'reject weapon spawn underflow'
    mov byte [player_y], WEAPON_HEIGHT
    call fire_bullet
    expect bullet_active, 0, 'reject weapon overlapping HUD'
    mov byte [player_y], 255
    call fire_bullet
    expect bullet_active, 0, 'reject invalid chef row'
    call initialize_player
    mov byte [player_x], 255
    call fire_bullet
    expect bullet_active, 0, 'reject invalid chef column'
    call initialize_player
    mov al, 255
    call spawn_player_weapon
    expect bullet_active, 0, 'reject invalid weapon kind'
    call fire_bullet
    mov byte [bullet_y], 2
    call update_bullets
    expect bullet_y, 1, 'shot reaches top playfield row'
    expect bullet_active, 1, 'top row visible for one frame'
    call update_bullets
    expect bullet_active, 0, 'remove shot leaving playfield'
    expect bullet_y, 1, 'no coordinate underflow'
    call update_bullets
    expect bullet_y, 1, 'inactive projectile stays still'
    mov byte [fire_cooldown], 0
    call fire_bullet
    mov byte [bullet_y], 255
    call update_bullets
    expect bullet_active, 0, 'discard invalid projectile row'
    mov byte [fire_cooldown], 0
    call fire_bullet
    mov byte [bullet_x], SCREEN_WIDTH - WEAPON_WIDTH + 1
    call update_bullets
    expect bullet_active, 0, 'discard projectile crossing right edge'

    call initialize_player
    call initialize_bullets
    mov byte [player_x], 20
    mov byte [fire_cooldown], 8
    call activate_player_powerup
    expect_word player_boost_frames, BOOST_FRAMES, 'boost duration'
    expect powerup_active, 1, 'boost active flag'
    expect fire_cooldown, 8, 'pickup cannot bypass a pending attack cooldown'
    call move_player_right
    expect player_x, 22, 'boost doubles right movement'
    call move_player_left
    expect player_x, 20, 'boost doubles left movement'
    mov byte [player_x], 1
    call move_player_left
    expect player_x, 0, 'boost does not underflow left edge'
    mov byte [player_x], SCREEN_WIDTH - PLAYER_WIDTH - 1
    call move_player_right
    expect player_x, SCREEN_WIDTH - PLAYER_WIDTH, 'boost does not overflow right edge'
    call initialize_bullets
    call fire_bullet
    expect bullets_damage, 2, 'boost doubles cleaver damage'
    expect fire_cooldown, BOOST_COOLDOWN, 'boosted burst has a full cooldown'
    expect bullets_active + 1, 1, 'boosted primary fires burst second shot'
    expect bullets_active + 2, 0, 'boost limits primary burst to two shots'
    expect bullets_y + 1, SCREEN_HEIGHT - PLAYER_HEIGHT - WEAPON_HEIGHT * 2 - 2, 'burst second shot spacing'
    expect bullets_damage + 1, 2, 'burst preserves boosted damage'
    mov cx, BOOST_COOLDOWN
    call tick_bullets
    expect fire_cooldown, 0, 'boosted cooldown expires in the full boost interval'
    call initialize_bullets
    call fire_secondary
    expect bullets_damage, 3, 'boost adds one rolling pin damage'
    expect fire_cooldown, BOOST_SECONDARY_COOLDOWN, 'boosted secondary retains slower cadence'
    expect bullet_active, 1, 'boosted secondary is active'
    mov cx, BOOST_FRAMES - 1
.timer:
    call update_player
    loop .timer
    expect_word player_boost_frames, 1, 'boost remains until final frame'
    call update_player
    expect_word player_boost_frames, 0, 'boost timer expires'
    expect powerup_active, 0, 'boost flag expires'
    expect bullets_damage, 3, 'in-flight damage survives boost expiry'
    mov byte [player_x], 20
    call move_player_right
    expect player_x, 21, 'movement returns to normal'
    call initialize_bullets
    call fire_bullet
    expect bullets_damage, 1, 'new shots return to normal damage'
    expect fire_cooldown, NORMAL_COOLDOWN, 'new shots return to normal rate'
    call activate_player_powerup
    call update_player
    call activate_player_powerup
    expect_word player_boost_frames, BOOST_FRAMES, 'new pickup refreshes duration'
    call initialize_player
    expect_word player_boost_frames, 0, 'restart clears boost timer'
    expect powerup_active, 0, 'restart clears boost flag'

    ; A burst at the highest valid firing position must never wrap into the HUD.
    call initialize_bullets
    call activate_player_powerup
    mov byte [player_y], PLAYFIELD_TOP + WEAPON_HEIGHT
    call fire_bullet
    expect bullets_y, 1, 'topmost primary spawn'
    expect bullets_y + 1, 1, 'burst second shot clamps at playfield top'
    mov byte [bullets_active + 2], 1 ; Fill the remaining pool slot before retrying.
    mov byte [fire_cooldown], 0
    call fire_bullet
    expect fire_cooldown, 0, 'blocked burst cannot reset cooldown'
    mov si, 1
    call remove_bullet_slot
    call fire_bullet
    expect bullets_active + 1, 1, 'partial pool burst fills available slot'
    expect fire_cooldown, BOOST_COOLDOWN, 'partial pool burst keeps cooldown'
    call initialize_player

    ; Repeated input must not bypass cooldown or fill the projectile pool.
    call initialize_player
    call initialize_bullets
    mov cx, 50
.spam:
    call fire_bullet
    loop .spam
    expect bullet_active, 1, 'spam allocates only one normal shot'
    expect bullets_active + 1, 0, 'spam cannot allocate a second shot'
    expect bullets_active + 2, 0, 'spam cannot allocate a third shot'
    expect fire_cooldown, NORMAL_COOLDOWN, 'spam leaves pending cooldown intact'
    call initialize_bullets
    call fire_secondary
    call activate_player_powerup
    expect fire_cooldown, SECONDARY_COOLDOWN, 'pickup cannot bypass long secondary cooldown'
    mov cx, BOOST_COOLDOWN
    call tick_bullets
    call fire_bullet
    expect bullets_active + 1, 0, 'primary cannot bypass pending secondary cooldown'
    call initialize_player

    ; Integration: collisions check sprite extent and all slots, not just slot zero.
    call initialize_bullets
    mov byte [enemy_x], 37
    mov byte [enemy_y], 4
    mov byte [enemy_health], 3
    mov byte [enemy_alive], 1
    mov word [score], 0
    mov byte [bullets_x + 1], 37 - WEAPON_WIDTH + 1
    mov byte [bullets_y + 1], 6
    mov byte [bullets_damage + 1], 2
    mov byte [bullets_active + 1], 1
    call check_bullet_enemy
    expect enemy_health, 1, 'apply damage from nonzero slot rectangle overlap'
    expect enemy_alive, 1, 'tough enemy survives weaker shot'
    expect bullets_active + 1, 0, 'consume colliding projectile'
    expect_word score, 0, 'no score before defeat'
    mov byte [bullets_x + 2], 37 - WEAPON_WIDTH
    mov byte [bullets_y + 2], 6
    mov byte [bullets_damage + 2], 4
    mov byte [bullets_active + 2], 1
    call check_bullet_enemy
    expect enemy_health, 1, 'touching rectangles do not overlap'
    expect bullets_active + 2, 1, 'missed projectile remains active'
    mov byte [bullets_x + 2], 37 - WEAPON_WIDTH + 1
    call check_bullet_enemy
    expect enemy_health, 0, 'lethal damage saturates health at zero'
    expect enemy_alive, 0, 'lethal damage removes enemy'
    expect_word score, 10, 'one defeat awards prototype score once'
    expect game_state, GAME_OVER, 'prototype round ends on defeat'
    call check_bullet_enemy
    expect_word score, 10, 'dead enemy cannot award score twice'

    ; Faster travel must still hit the narrow target, with unchanged damage.
    call initialize_player
    call initialize_bullets
    mov byte [game_state], PLAYING
    mov byte [enemy_x], (SCREEN_WIDTH - ENEMY_WIDTH) / 2
    mov byte [enemy_health], INITIAL_ENEMY_HEALTH
    mov byte [enemy_alive], 1
    mov word [score], 0
    call fire_bullet
    mov byte [bullet_y], 14
    call check_bullet_enemy
    expect enemy_health, INITIAL_ENEMY_HEALTH, 'distant shot has not hit yet'
    mov cx, 3
.fast_hit:
    call update_bullets
    call check_bullet_enemy
    loop .fast_hit
    expect bullet_y, 5, 'three updates move nine rows'
    expect enemy_health, INITIAL_ENEMY_HEALTH - 1, 'fast smaller cleaver still hits for one damage'
    expect bullet_active, 0, 'fast hit consumes its projectile'
    expect fire_cooldown, NORMAL_COOLDOWN - 3, 'speed does not accelerate cooldown ticking'
    expect_word score, 0, 'fast shot does not award premature score'
    call initialize_bullets
    call fire_secondary
    mov byte [bullet_y], PLAYFIELD_TOP + BULLET_SPEED
    call update_bullets
    expect bullet_y, PLAYFIELD_TOP, 'full speed step ends at top boundary'
    expect bullet_active, 1, 'top boundary retains one visible frame'
    call update_bullets
    expect bullet_active, 0, 'remove fast secondary after its final top frame'

    ; The rebalanced demo target takes eight cleavers or four rolling pins.
    call initialize_player
    call initialize_bullets
    mov byte [game_state], PLAYING
    mov byte [enemy_x], (SCREEN_WIDTH - ENEMY_WIDTH) / 2
    mov byte [enemy_health], INITIAL_ENEMY_HEALTH
    mov byte [enemy_alive], 1
    mov word [score], 0
    mov cx, 7
.cleaver_hits:
    mov byte [fire_cooldown], 0
    call fire_bullet
    mov byte [bullet_y], 4
    call check_bullet_enemy
    loop .cleaver_hits
    expect enemy_health, 1, 'seven cleavers leave one health'
    expect enemy_alive, 1, 'seven cleavers cannot finish the stronger target'
    expect_word score, 0, 'surviving target awards no score'
    mov byte [fire_cooldown], 0
    call fire_bullet
    mov byte [bullet_y], 4
    call check_bullet_enemy
    expect enemy_health, 0, 'eighth cleaver defeats the target'
    expect_word score, 10, 'eight cleavers award one defeat'
    call initialize_bullets
    mov byte [game_state], PLAYING
    mov byte [enemy_health], INITIAL_ENEMY_HEALTH
    mov byte [enemy_alive], 1
    mov word [score], 0
    mov cx, 3
.pin_hits:
    mov byte [fire_cooldown], 0
    call fire_secondary
    mov byte [bullet_y], 4
    call check_bullet_enemy
    loop .pin_hits
    expect enemy_health, 2, 'three rolling pins leave two health'
    expect enemy_alive, 1, 'three pins cannot finish the stronger target'
    expect_word score, 0, 'three pins award no premature score'
    mov byte [fire_cooldown], 0
    call fire_secondary
    mov byte [bullet_y], 4
    call check_bullet_enemy
    expect enemy_health, 0, 'fourth rolling pin defeats the target'
    expect_word score, 10, 'four pins award one defeat'

    ; Register contracts required by callers.
    mov bx, 1234h
    mov si, 5678h
    mov di, 9ABCh
    call initialize_bullets
    call update_bullets
    call remove_bullet
    expect_reg bx, 1234h, 'bullet update preserves BX'
    expect_reg si, 5678h, 'bullet updates preserve SI'
    expect_reg di, 9ABCh, 'bullet updates preserve DI'
    mov byte [game_state], PLAYING
    call initialize_player
    call fire_bullet
    expect_reg bx, 1234h, 'spawning preserves BX'
    expect_reg si, 5678h, 'spawning preserves SI'
    ; Rendering integration: every document character must survive unchanged.
    call clear_screen
    expect_word render_cursor, 0, 'frame clear resets drawing cursor'
    expect_word render_buffer, 0720h, 'frame clear blanks top left'
    expect_word render_buffer + (SCREEN_WIDTH * SCREEN_HEIGHT - 1) * 2, 0720h, 'frame clear blanks bottom right'
    mov dh, SCREEN_HEIGHT - 2
    mov dl, SCREEN_WIDTH - PLAYER_WIDTH
    call set_cursor
    expect_word render_cursor, ((SCREEN_HEIGHT - 2) * SCREEN_WIDTH + SCREEN_WIDTH - PLAYER_WIDTH) * 2, 'text cursor row and column calculation'
    mov byte [player_x], SCREEN_WIDTH - PLAYER_WIDTH
    mov byte [player_y], SCREEN_HEIGHT - PLAYER_HEIGHT - 1
    call draw_player
    expect_word render_buffer + ((SCREEN_HEIGHT - PLAYER_HEIGHT - 1) * SCREEN_WIDTH + SCREEN_WIDTH - PLAYER_WIDTH + 2) * 2, 0F23h, 'chef preserves original hat character'
    expect_word render_buffer + ((SCREEN_HEIGHT - 2) * SCREEN_WIDTH + SCREEN_WIDTH - 1) * 2, 0F23h, 'chef fits bottom-right legal position'
    expect_word render_buffer + ((SCREEN_HEIGHT - 1) * SCREEN_WIDTH) * 2, 0720h, 'chef does not wrap onto following row'
    mov si, source_player_art
    mov di, render_buffer + ((SCREEN_HEIGHT - PLAYER_HEIGHT - 1) * SCREEN_WIDTH + SCREEN_WIDTH - PLAYER_WIDTH) * 2
    mov bl, 0Fh
    mov dx, chef_render_failed
    call verify_document_sprite
    call clear_screen
    call initialize_bullets
    mov byte [bullets_x], 0
    mov byte [bullets_y], 1
    mov byte [bullets_active], 1
    mov byte [bullets_kind], ROLLING_PIN
    mov byte [bullets_damage], 2
    call draw_bullet
    expect_word render_buffer + (2 * SCREEN_WIDTH + 2) * 2, 0E23h, 'rolling pin art drawn in yellow'
    expect_word render_buffer, 0720h, 'weapon avoids HUD row'
    mov si, expected_pin_sprite
    mov di, render_buffer + SCREEN_WIDTH * 2
    mov bl, 0Eh
    mov dx, pin_render_failed
    call verify_weapon_sprite
    mov byte [bullets_damage], 3
    call draw_bullet
    expect_word render_buffer + (2 * SCREEN_WIDTH + 2) * 2, 0C23h, 'boosted weapon drawn in red'
    mov byte [bullets_kind], CLEAVER
    mov byte [bullets_damage], 1
    call draw_bullet
    expect_word render_buffer + (SCREEN_WIDTH + 1) * 2, 0B23h, 'smaller cleaver art drawn in cyan'
    mov si, expected_cleaver_sprite
    mov di, render_buffer + SCREEN_WIDTH * 2
    mov bl, 0Bh
    mov dx, cleaver_render_failed
    call verify_weapon_sprite
    expect_word render_buffer + (SCREEN_WIDTH + WEAPON_WIDTH) * 2, 0720h, 'smaller weapon leaves neighboring column clear'
    expect_word render_buffer + ((PLAYFIELD_TOP + WEAPON_HEIGHT) * SCREEN_WIDTH) * 2, 0720h, 'smaller weapon leaves following row clear'
    call clear_screen
    mov byte [bullets_kind], ROLLING_PIN
    mov byte [bullets_damage], 2
    mov byte [bullets_x], SCREEN_WIDTH - WEAPON_WIDTH
    mov byte [bullets_y], SCREEN_HEIGHT - WEAPON_HEIGHT - 1
    call draw_bullet
    mov si, expected_pin_sprite
    mov di, render_buffer + ((SCREEN_HEIGHT - WEAPON_HEIGHT - 1) * SCREEN_WIDTH + SCREEN_WIDTH - WEAPON_WIDTH) * 2
    mov bl, 0Eh
    mov dx, pin_render_failed
    call verify_weapon_sprite
    expect_word render_buffer + ((SCREEN_HEIGHT - 2) * SCREEN_WIDTH + SCREEN_WIDTH - 1) * 2, 0E20h, 'smaller weapon fits bottom-right without clipping'
    expect_word render_buffer + ((SCREEN_HEIGHT - 1) * SCREEN_WIDTH) * 2, 0720h, 'smaller weapon avoids footer at bottom-right'
    call initialize_player
    call initialize_bullets
    mov byte [game_state], PLAYING
    mov byte [enemy_health], INITIAL_ENEMY_HEALTH
    call draw_game
    expect_word render_buffer + 12 * 2, 0752h, 'HUD shows READY when cooldown is clear'
    expect_word render_buffer + ((SCREEN_WIDTH - 12) / 2 + 11) * 2, 0730h + INITIAL_ENEMY_HEALTH, 'HUD shows the tougher eight-health target'
    call fire_bullet
    call draw_game
    expect_word render_buffer + 12 * 2, 0757h, 'HUD shows WAIT while attack is cooling down'
    ; Hardware copy must reach both halves of the expanded VGA text page.
    mov word [render_buffer], 0741h
    mov word [render_buffer + SCREEN_WIDTH * 60 * 2], 0742h
    mov word [render_buffer + (SCREEN_WIDTH * SCREEN_HEIGHT - 1) * 2], 0743h
    call present_frame
    mov ax, 0B800h
    mov es, ax
    mov ax, [es:0]
    expect_reg ax, 0741h, 'VGA copy includes first cell'
    mov ax, [es:SCREEN_WIDTH * 60 * 2]
    expect_reg ax, 0742h, 'VGA copy includes second half of the taller field'
    mov ax, [es:(SCREEN_WIDTH * SCREEN_HEIGHT - 1) * 2]
    expect_reg ax, 0743h, 'VGA copy reaches the bottom-right cell without wrapping'
    mov ax, 3
    int 10h
    mov dx, passed
    mov ah, 09h
    int 21h
    mov ax, 4C00h
    int 21h

; Compare all 192 source characters, including spaces and their colors.
; SI=independent document reference, DI=frame start, BL=color, DX=failure text.
verify_document_sprite:
    mov cx, SOURCE_ART_HEIGHT
.row:
    mov bp, SOURCE_ART_WIDTH
.cell:
    lodsb
    mov ah, bl
    cmp [di], ax
    jne fail
    add di, 2
    dec bp
    jnz .cell
    add di, (SCREEN_WIDTH - SOURCE_ART_WIDTH) * 2
    loop .row
    ret
; Compare independent 6x8 silhouette references, including all blank cells.
verify_weapon_sprite:
    mov cx, WEAPON_HEIGHT
.row:
    mov bp, WEAPON_WIDTH
.cell:
    lodsb
    mov ah, bl
    cmp [di], ax
    jne fail
    add di, 2
    dec bp
    jnz .cell
    add di, (SCREEN_WIDTH - WEAPON_WIDTH) * 2
    loop .row
    ret
expected_cleaver_sprite:
    db ' #####', '######', '######', ' #####'
    db '  ### ', '  ### ', '  ### ', '   #  '
expected_pin_sprite:
    db ' #### ', '######', '######', '######'
    db '######', '######', '######', ' #### '
chef_render_failed db 'FAIL: every chef character and space matches the document',13,10,'$'
pin_render_failed db 'FAIL: smaller rolling pin silhouette and spacing are correct',13,10,'$'
cleaver_render_failed db 'FAIL: smaller cleaver silhouette and spacing are correct',13,10,'$'

tick_bullets:
    call update_bullets
    loop tick_bullets
    ret
video_failed:
    mov dx, video_failed_text
fail:
    push dx
    mov ax, 3
    int 10h
    pop dx
    mov ah, 09h
    int 21h
    mov ax, 4C01h
    int 21h
video_failed_text db 'FAIL: enlarged SVGA display initialization',13,10,'$'
passed: db 'PASS: Food Invaders player, dual weapons, boosts and collision tests', 13, 10, '$'
