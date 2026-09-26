; Small, explicit extension points for future optional gameplay features.

; -------------------------------------------------
; Procedure: update_features
; Purpose: Update optional feature state once per game loop.
; Input: None
; Output: No behavior yet; placeholder for shield/power-up timers.
; Modifies: None
; Shared variables used: shield_active, powerup_active
; -------------------------------------------------
update_features:
    ret

; -------------------------------------------------
; Procedure: activate_shield
; Purpose: Mark the future shield feature as active.
; Input: None
; Output: shield_active becomes 1.
; Modifies: AX
; Shared variables used: shield_active
; -------------------------------------------------
activate_shield:
    mov byte [shield_active], 1
    ret

; -------------------------------------------------
; Procedure: deactivate_shield
; Purpose: Mark the future shield feature as inactive.
; Input: None
; Output: shield_active becomes 0.
; Modifies: AX
; Shared variables used: shield_active
; -------------------------------------------------
deactivate_shield:
    mov byte [shield_active], 0
    ret
