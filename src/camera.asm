; camera.asm - owner: Yahya Masood - stub, filled in later
; ==========================================================================
; FILE    : src/camera.asm
; OWNER   : Yahya Masood (Module 6)
; PURPOSE : Camera and scrolling (PDF Section 5.3).
;           Mario always moves in WORLD coordinates. The camera is the world
;           x of the left edge of the screen (variable camera_x, whole
;           pixels, in data_engine.asm). The screen position of anything is
;               screen_x = world_x - camera_x
;           Parameters go on the stack. Only whole pixels are used (the
;           fraction byte of Mario's x is never passed in), so the picture
;           does not jitter.
; ==========================================================================

; --------------------------------------------------------------------------
; Procedure : ResetCamera
; Purpose   : Put the camera back at the start of the level (camera_x = 0).
;             Must be called on every new life and every new game.
; Inputs    : none
; Outputs   : camera_x = 0
; Registers : none changed
; --------------------------------------------------------------------------
ResetCamera:
        mov  word [camera_x], 0         ; left edge of the screen = world x 0
        ret

; --------------------------------------------------------------------------
; Procedure : UpdateCamera
; Purpose   : Move the camera once per frame, after Mario has moved.
;             1. screen_x = mario_world_x - camera_x
;             2. if screen_x > 160, new_camera = mario_world_x - 160
;                (otherwise the camera stays where it is)
;             3. if new_camera > 640 (level width - 320), new_camera = 640
;             4. the camera never moves left: it only changes when
;                new_camera is bigger than the current camera_x
; Inputs    : push mario_world_x (whole pixels)
;             [bp+4] = mario_world_x
; Outputs   : camera_x updated
; Registers : none changed (AX, BX, BP saved and restored)
; Note      : "ret 2" removes the 1 parameter word from the stack.
; --------------------------------------------------------------------------
UpdateCamera:
        push bp
        mov  bp, sp
        push ax
        push bx

        mov  bx, [bp+4]                 ; BX = Mario's world x
        mov  ax, bx
        sub  ax, [camera_x]             ; AX = screen_x (can be negative)
        cmp  ax, CAMERA_FOLLOW_X        ; screen_x > 160 ? (signed compare)
        jle  .done                      ; no: the camera stays

        mov  ax, bx
        sub  ax, CAMERA_FOLLOW_X        ; AX = new_camera = world_x - 160
        cmp  ax, CAMERA_MAX             ; new_camera > 640 ? (unsigned)
        jbe  .not_too_far
        mov  ax, CAMERA_MAX             ; yes: stop at the last camera position
.not_too_far:
        cmp  ax, [camera_x]             ; new_camera > camera_x ?
        jbe  .done                      ; no: never move the camera left
        mov  [camera_x], ax             ; yes: the camera follows Mario

.done:
        pop  bx
        pop  ax
        pop  bp
        ret  2

; --------------------------------------------------------------------------
; Procedure : KeepInsideLeftEdge
; Purpose   : Left wall (step 5): Mario may not go left of the screen edge.
;             If mario_world_x < camera_x the result is camera_x.
; Inputs    : push mario_world_x (whole pixels)
;             [bp+4] = mario_world_x
; Outputs   : AX = the corrected world x (the input if it was fine)
; Registers : only AX changed (BP saved and restored)
; Note      : The caller must store AX in hero_x, and when AX is different
;             from the input it must also set Mario's horizontal speed
;             (hero_vx) to 0, as the PDF requires. Call it after
;             UpdateCamera. "ret 2" removes the 1 parameter word.
; --------------------------------------------------------------------------
KeepInsideLeftEdge:
        push bp
        mov  bp, sp

        mov  ax, [bp+4]                 ; AX = Mario's world x
        cmp  ax, [camera_x]             ; Mario left of the screen edge?
        jae  .done                      ; no: keep his x
        mov  ax, [camera_x]             ; yes: put him at the edge

.done:
        pop  bp
        ret  2

; --------------------------------------------------------------------------
; Procedure : WorldToScreenX
; Purpose   : Convert the world x of an enemy, shell, mushroom or coin to a
;             screen x, and tell whether it must be drawn:
;             visible only when -16 < screen_x < 320.
; Inputs    : push world_x (whole pixels)
;             [bp+4] = world_x
; Outputs   : AX = screen_x = world_x - camera_x (signed)
;             DX = 1 if the object is visible, 0 if it must not be drawn
; Registers : only AX and DX changed (BP saved and restored)
; Note      : "ret 2" removes the 1 parameter word from the stack.
; --------------------------------------------------------------------------
WorldToScreenX:
        push bp
        mov  bp, sp

        mov  ax, [bp+4]                 ; AX = world x
        sub  ax, [camera_x]             ; AX = screen_x
        mov  dx, 0                      ; assume: not visible
        cmp  ax, -TILE_SIZE             ; screen_x <= -16 ? (signed compare)
        jle  .done                      ; yes: completely off the left side
        cmp  ax, SCREEN_WIDTH           ; screen_x >= 320 ?
        jge  .done                      ; yes: completely off the right side
        mov  dx, 1                      ; visible

.done:
        pop  bp
        ret  2