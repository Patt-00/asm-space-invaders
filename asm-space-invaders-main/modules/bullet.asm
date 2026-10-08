; Developer 2: bounded projectile pool, dual weapons, and boosted attack stats.
; All procedures require DS to address variables.inc. No rendering or interrupts.

; Procedure: initialize_bullets
; Purpose: Clear all projectile slots, metadata, and cooldown on restart.
; Input: None. Output: No active projectiles.
; Modifies: Flags only; all general-purpose registers preserved.
; Shared: bullets_x/y/active/kind/damage, fire_cooldown.
initialize_bullets:
    push si
    xor si, si
.loop:
    mov byte [bullets_x + si], 0
    mov byte [bullets_y + si], 0
    mov byte [bullets_active + si], 0
    mov byte [bullets_kind + si], CLEAVER
    mov byte [bullets_damage + si], 0
    inc si
    cmp si, MAX_BULLETS
    jb .loop
    mov byte [fire_cooldown], 0
    pop si
    ret

; Procedure: fire_bullet
; Purpose: Fire a cleaver (Space), or a two-shot burst while boosted.
; Input: None. Output: Up to two free slots filled when state/cooldown allow it.
; Modifies: AX, flags; all other general-purpose registers preserved.
; Shared: Same as spawn_player_weapon.
fire_bullet:
    mov al, CLEAVER
    call spawn_player_weapon
    jc .done
    cmp word [player_boost_frames], 0
    je .done
    push bx
    push cx
    push si
    mov bx, WEAPON_HEIGHT + 1  ; Keep burst sprites separate.
    mov cx, BOOST_BURST_COUNT - 1
.burst:
    mov byte [fire_cooldown], 0
    mov al, CLEAVER
    call spawn_player_weapon
    mov byte [fire_cooldown], BOOST_COOLDOWN
    jc .restore
    mov si, ax
    mov al, [bullets_y + si]
    cmp al, bl
    jbe .top
    sub al, bl
    jmp .position
.top:
    mov al, PLAYFIELD_TOP
.position:
    mov [bullets_y + si], al
    add bl, WEAPON_HEIGHT + 1
    loop .burst
.restore:
    pop si
    pop cx
    pop bx
.done:
    ret

; Procedure: fire_secondary
; Purpose: Fire the rolling pin (X), as labeled in the document's weapon art.
; Input: None. Output: One free slot filled if position/state/cooldown allow it.
; Modifies: AX, flags. Shared: Same as spawn_player_weapon.
fire_secondary:
    mov al, ROLLING_PIN
    jmp spawn_player_weapon

; Procedure: spawn_player_weapon
; Purpose: Allocate a projectile without overwriting active shots or wrapping.
; Input: AL = CLEAVER or ROLLING_PIN. Output: CF=0 and AX=allocated slot,
;         or CF=1 when blocked; new sprite centered above the chef.
; Modifies: AX, flags (BX and SI preserved).
; Shared: game_state, player_x/y, player_boost_frames, fire_cooldown,
;         bullets_x/y/active/kind/damage.
spawn_player_weapon:
    cmp byte [game_state], PLAYING
    jne .done
    cmp byte [fire_cooldown], 0
    jne .done
    cmp al, ROLLING_PIN
    ja .done
    cmp byte [player_x], SCREEN_WIDTH - PLAYER_WIDTH
    ja .done
    cmp byte [player_y], PLAYFIELD_TOP + WEAPON_HEIGHT
    jb .done
    cmp byte [player_y], SCREEN_HEIGHT - PLAYER_HEIGHT - 1
    ja .done
    push bx
    push si
    mov bl, al
    xor si, si
.find:
    cmp byte [bullets_active + si], 0
    je .spawn
    inc si
    cmp si, MAX_BULLETS
    jb .find
    jmp .blocked
.spawn:
    mov [bullets_kind + si], bl
    mov al, [player_x]
    add al, (PLAYER_WIDTH - WEAPON_WIDTH) / 2
    mov [bullets_x + si], al
    mov al, [player_y]
    sub al, WEAPON_HEIGHT
    mov [bullets_y + si], al
    mov al, 1                  ; Cleaver = 1 damage, rolling pin = 2.
    add al, bl
    mov byte [fire_cooldown], NORMAL_COOLDOWN
    cmp bl, ROLLING_PIN
    jne .boost
    mov byte [fire_cooldown], SECONDARY_COOLDOWN
.boost:
    cmp word [player_boost_frames], 0
    je .publish
    inc al                     ; Boost adds one damage, avoiding a 4-damage pin.
    mov byte [fire_cooldown], BOOST_COOLDOWN
    cmp bl, ROLLING_PIN
    jne .publish
    mov byte [fire_cooldown], BOOST_SECONDARY_COOLDOWN
.publish:
    mov [bullets_damage + si], al
    mov byte [bullets_active + si], 1
    mov ax, si
    clc
    jmp .restore
.blocked:
    stc
.restore:
    pop si
    pop bx
    ret
.done:
    stc
    ret

; Procedure: update_bullets
; Purpose: Tick cooldown and move all active shots upward BULLET_SPEED rows.
; Input: None. Output: Out-of-bounds slots removed; no coordinate underflow.
; Modifies: Flags only; all general-purpose registers preserved.
; Shared: fire_cooldown, bullets_x/y/active/damage.
update_bullets:
    cmp byte [fire_cooldown], 0
    je .slots
    dec byte [fire_cooldown]
.slots:
    push si
    xor si, si
.loop:
    cmp byte [bullets_active + si], 1
    jne .next
    cmp byte [bullets_x + si], SCREEN_WIDTH - WEAPON_WIDTH
    ja .remove
    cmp byte [bullets_y + si], SCREEN_HEIGHT - WEAPON_HEIGHT - 1
    ja .remove
    cmp byte [bullets_y + si], PLAYFIELD_TOP
    jbe .remove
    cmp byte [bullets_y + si], PLAYFIELD_TOP + BULLET_SPEED
    jbe .top
    sub byte [bullets_y + si], BULLET_SPEED
    jmp .next
.top:
    mov byte [bullets_y + si], PLAYFIELD_TOP ; Last visible frame, no underflow.
    jmp .next
.remove:
    call remove_bullet_slot
.next:
    inc si
    cmp si, MAX_BULLETS
    jb .loop
    pop si
    ret

; Procedure: remove_bullet
; Purpose: Compatibility wrapper to remove slot zero.
; Input: None. Output: Slot zero inactive with zero damage.
; Modifies: Flags only; all general-purpose registers preserved.
; Shared: bullets_active, bullets_damage.
remove_bullet:
    push si
    xor si, si
    call remove_bullet_slot
    pop si
    ret

; Procedure: remove_bullet_slot
; Purpose: Clear an indexed slot; safely ignore invalid indices.
; Input: SI = slot index. Output: Slot inactive with zero damage.
; Modifies: Flags only; all general-purpose registers preserved.
; Shared: bullets_active, bullets_damage.
remove_bullet_slot:
    cmp si, MAX_BULLETS
    jae .done
    mov byte [bullets_active + si], 0
    mov byte [bullets_damage + si], 0
.done:
    ret
