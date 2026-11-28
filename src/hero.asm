; ==========================================================================
; FILE    : src/hero.asm
; OWNER   : Sami Ahsan (Module 9)
; PURPOSE : Mario's movement and physics (PDF Section 5.2, Appendix A.5).
;           Call UpdateHero once per frame (frame step 3).
;           All variables are in data_game.asm:
;             hero_x . hero_x_frac  world x (whole pixels + fraction byte)
;             hero_y                top of Mario, 8.8 fixed point
;             hero_vx, hero_vy      speeds, signed 8.8 fixed point
;           A speed is stored as value * 256: high byte = whole pixels,
;           low byte = 1/256 pixel. A negative speed is two's complement.
;           Signed numbers are compared with JG/JL/JGE/JLE, positions
;           (unsigned) with JA/JB/JAE/JBE.
; NOTE    : Tile collision (Module 10) is in collision.asm. UpdateHero
;           calls ResolveHeroX after MoveHeroX and ResolveHeroY after
;           MoveHeroY, so Mario moves one axis at a time (PDF 5.6 tip).
; ==========================================================================

; --------------------------------------------------------------------------
; Procedure : UpdateHero
; Purpose   : One frame of Mario's physics, in the order of PDF 5.13 step 3:
;             remember the feet, horizontal speed, gravity and jump,
;             move x and resolve walls, move y and resolve floor/ceiling, pose.
; Inputs    : none (reads key_table and the hero variables)
; Outputs   : hero variables updated
; Registers : none changed
; --------------------------------------------------------------------------
UpdateHero:
        call SaveHeroFeet               ; Module 10: feet before this frame
        call UpdateHeroSpeedX           ; walk, run, brake, friction, facing
        call UpdateHeroSpeedY           ; gravity, jump, variable jump height
        call MoveHeroX                  ; x = x + vx (and level edges)
        call ResolveHeroX               ; Module 10: walls
        call MoveHeroY                  ; y = y + vy
        call ResolveHeroY               ; Module 10: floor, ceiling, head hit
        call UpdateHeroPose             ; which sprite to show
        ret

; --------------------------------------------------------------------------
; Procedure : UpdateHeroSpeedX
; Purpose   : Change the horizontal speed hero_vx (PDF 5.2):
;             - Right only held : accelerate right, facing = right
;             - Left only held  : accelerate left,  facing = left
;               (if Mario moves the other way, brake faster instead)
;             - the speed never goes above the limit: walk speed, or run
;               speed while Left Shift is held
;             - no direction held (or both): friction slows Mario down to 0
;             Works in the air too (air control).
; Inputs    : none (reads key_table)
; Outputs   : hero_vx, hero_facing
; Registers : none changed (AX, BX saved and restored)
; Logic     : AX = speed, BX = speed limit
; --------------------------------------------------------------------------
UpdateHeroSpeedX:
        push ax
        push bx

        mov  ax, [hero_vx]              ; AX = current speed
        mov  bx, PHYS_MAX_WALK          ; BX = speed limit (walking)
        cmp  byte [key_table+KEY_LSHIFT], 0
        je   .limit_ready               ; Shift not held: walking limit
        mov  bx, PHYS_MAX_RUN           ; Shift held: running limit
.limit_ready:

        cmp  byte [key_table+KEY_RIGHT], 0
        je   .right_not_held
        cmp  byte [key_table+KEY_LEFT], 0
        je   .go_right                  ; only Right is held
        jmp  .friction                  ; both held: counts as no direction
.right_not_held:
        cmp  byte [key_table+KEY_LEFT], 0
        jne  .go_left                   ; only Left is held

; ---- no direction: friction brings the speed to 0 ------------------------
.friction:
        cmp  ax, 0
        jg   .friction_right            ; moving right
        jl   .friction_left             ; moving left
        jmp  .store                     ; speed is already 0
.friction_right:
        cmp  ax, PHYS_FRICTION          ; speed <= friction ?
        jbe  .stop                      ; yes: stop (never go below 0)
        sub  ax, PHYS_FRICTION          ; no: slow down a little
        jmp  .store
.friction_left:
        neg  ax                         ; AX = speed without the minus sign
        cmp  ax, PHYS_FRICTION
        jbe  .stop
        sub  ax, PHYS_FRICTION
        neg  ax                         ; put the minus sign back
        jmp  .store
.stop:
        mov  ax, 0
        jmp  .store

; ---- Right held ----------------------------------------------------------
.go_right:
        mov  byte [hero_facing], FACING_RIGHT
        cmp  ax, 0
        jl   .brake_right               ; moving left: brake
        add  ax, PHYS_WALK_ACCEL        ; accelerate
        jmp  .cap_right
.brake_right:
        add  ax, PHYS_BRAKE             ; brake (stronger than friction)
.cap_right:
        cmp  ax, bx                     ; faster than the limit?
        jle  .store
        mov  ax, bx                     ; yes: limit the speed
        jmp  .store

; ---- Left held -----------------------------------------------------------
.go_left:
        mov  byte [hero_facing], FACING_LEFT
        cmp  ax, 0
        jg   .brake_left                ; moving right: brake
        sub  ax, PHYS_WALK_ACCEL        ; accelerate to the left
        jmp  .cap_left
.brake_left:
        sub  ax, PHYS_BRAKE
.cap_left:
        neg  bx                         ; BX = - limit
        cmp  ax, bx                     ; faster (to the left) than the limit?
        jge  .store
        mov  ax, bx                     ; yes: limit the speed

.store:
        mov  [hero_vx], ax

        pop  bx
        pop  ax
        ret

; --------------------------------------------------------------------------
; Procedure : UpdateHeroSpeedY
; Purpose   : Change the vertical speed hero_vy (PDF 5.2). Up is negative.
;             1. Gravity: vy = vy + gravity, but never more than the maximum
;                fall speed.
;             2. Jump: only when Mario stands on the ground (no double jump)
;                and Space is held: vy = jump start speed.
;             3. Variable jump height: while Mario rises and Space is NOT
;                held, an upward speed faster than the cut-off is cut to the
;                cut-off. A short tap gives a small hop, holding the full jump.
; Inputs    : none (reads key_table, on_ground)
; Outputs   : hero_vy, on_ground
; Registers : none changed
; --------------------------------------------------------------------------
UpdateHeroSpeedY:
        add  word [hero_vy], PHYS_GRAVITY ; gravity
        cmp  word [hero_vy], PHYS_MAX_FALL
        jle  .gravity_done              ; not faster than the maximum
        mov  word [hero_vy], PHYS_MAX_FALL
.gravity_done:

        cmp  byte [on_ground], 0
        je   .jump_done                 ; in the air: no jump
        cmp  byte [key_table+KEY_SPACE], 0
        je   .jump_done                 ; Space not held: no jump
        mov  word [hero_vy], PHYS_JUMP_START
        mov  byte [on_ground], 0        ; Mario leaves the ground
.jump_done:

        cmp  byte [key_table+KEY_SPACE], 0
        jne  .done                      ; Space held: keep the full jump
        cmp  word [hero_vy], PHYS_JUMP_CUTOFF
        jge  .done                      ; not rising faster than the cut-off
        mov  word [hero_vy], PHYS_JUMP_CUTOFF ; cut the jump short
.done:
        ret

; --------------------------------------------------------------------------
; Procedure : MoveHeroX
; Purpose   : Add the horizontal speed to the position:
;               fraction byte = fraction byte + low byte of vx   (may carry)
;               whole word    = whole word + high byte of vx (sign extended)
;                               + carry
;             Then keep Mario inside the level: he cannot go left of x = 0
;             or right of the last tile (x = 944). Reaching an end sets the
;             horizontal speed to 0.
;             (The wall at the left edge of the SCREEN is Module 6,
;              KeepInsideLeftEdge, called after the camera update.)
; Inputs    : none
; Outputs   : hero_x, hero_x_frac, hero_vx
; Registers : none changed (AX saved and restored)
; Note      : MOV and CBW do not change the carry flag, so the carry of the
;             ADD reaches the ADC.
; --------------------------------------------------------------------------
MoveHeroX:
        push ax

        mov  ax, [hero_vx]              ; AL = fraction of vx, AH = whole part
        add  [hero_x_frac], al          ; fraction + fraction (may set carry)
        mov  al, ah                     ; AL = whole part of vx
        cbw                             ; AX = whole part as a 16 bit number
        adc  [hero_x], ax               ; x = x + whole part + carry

        test word [hero_x], 8000h       ; x below 0 looks like a huge number
        jz   .check_right
        mov  word [hero_x], 0           ; left end of the level
        mov  byte [hero_x_frac], 0
        mov  word [hero_vx], 0
        jmp  .done
.check_right:
        cmp  word [hero_x], LEVEL_WIDTH_PX-TILE_SIZE
        jb   .done                      ; still left of the last position
        mov  word [hero_x], LEVEL_WIDTH_PX-TILE_SIZE ; right end of the level
        mov  byte [hero_x_frac], 0
        mov  word [hero_vx], 0
.done:
        pop  ax
        ret

; --------------------------------------------------------------------------
; Procedure : MoveHeroY
; Purpose   : Add the vertical speed to the position: y = y + vy (8.8 add).
;             Floor and ceiling are handled by ResolveHeroY (Module 10),
;             which also sets on_ground.
; Inputs    : none
; Outputs   : hero_y
; Registers : none changed (AX saved and restored)
; --------------------------------------------------------------------------
MoveHeroY:
        push ax

        mov  ax, [hero_vy]
        add  [hero_y], ax               ; y = y + vy

        pop  ax
        ret

; --------------------------------------------------------------------------
; Procedure : UpdateHeroPose
; Purpose   : Choose the pose (PDF 5.2): jumping sprite in the air, running
;             sprite when moving on the ground, standing sprite when still.
; Inputs    : none
; Outputs   : hero_pose
; Registers : none changed
; --------------------------------------------------------------------------
UpdateHeroPose:
        cmp  byte [on_ground], 0
        je   .in_air
        cmp  word [hero_vx], 0
        jne  .running
        mov  byte [hero_pose], POSE_STAND
        ret
.running:
        mov  byte [hero_pose], POSE_RUN
        ret
.in_air:
        mov  byte [hero_pose], POSE_JUMP
        ret