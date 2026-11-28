
; ==========================================================================
; FILE    : src/mario.asm
; PROJECT : Super Mario Engine (COAL semester project)
; OWNER   : Yahya Masood (Module 1)
; PURPOSE : Main program. Only this file is given to NASM. It includes all
;           other source files so that one MARIO.COM is produced.
; BUILD   : build.bat
; ==========================================================================

bits 16
       org  100h

; ---- 1. Constants --------------------------------------------------------
%include "const_engine.asm"
%include "const_game.asm"

; ---- 2. Program entry point ---------------------------------------------
start:
       call InitFrameBuffer
       call InstallKeyboardHandler     ; Module 7: our own INT 09h routine
        
        call InstallTimerHandler        ; Module 8: timer tick and game clock
       call SetVideoMode13

        call ResetMap
        mov  ax, 0
        push ax
        call DrawMap

        mov  ax, 100
        push ax
        mov  ax, 100
        push ax
        mov  ax, sprite_mario_stand
        push ax
        mov  ax, 0
        push ax
        call DrawSprite

        call CopyFrameToScreen
        call ResetMap  ; Module 3: working map = original map
        call ResetEnemies                 
        call ResetBlockItems            ; Module 12: no mushrooms, no coin pop
        call ClearFrameBuffer           ; the bottom 8 rows stay black

       ; Module 8: start the game clock for the new life
       mov  word [time_left], 300
       mov  byte [ticks_this_second], 0
       mov  byte [clock_running], 1

        ; ---- Main loop (frame order of PDF 5.13). Module 14 will replace
        ;      this loop by the state machine. ------------------------------
.game_loop:
                call UpdateHero
        call HandleHeadHit              ; Module 12
        call CollectCoins               ; Module 12

        call UpdateEnemies
        call UpdateMushrooms            ; Module 12

        call ResolveHeroEnemies
        call ResolveHeroMushrooms       ; Module 12

        call UpdateInvulnerability
        call UpdatePopCoin              ; Module 12
        mov  ax, [hero_x]               ; step 8: Module 6 camera
        push ax
        call UpdateCamera
        mov  ax, [hero_x]
        push ax
        call KeepInsideLeftEdge         ; AX = x, not left of the screen edge
        cmp  ax, [hero_x]
        je   .wall_done
        mov  [hero_x], ax               ; pushed back by the left screen wall
        mov  byte [hero_x_frac], 0
        mov  word [hero_vx], 0
.wall_done:

        mov  ax, [camera_x]             ; step 9: draw the level and Mario
        push ax
        call DrawMap
        call DrawPopCoin                ; Module 12
        call DrawMushrooms              ; Module 12
        call DrawEnemies                ; step 9: draw enemies on framebuffer

                mov  bh, [hero_pose]            ; BX = pose * 256: the sprites are in
        mov  bl, 0                      ; the order stand, run, jump
        mov  ax, sprite_mario_stand
        mov  dx, 0                      ; flags: facing right
        cmp  byte [form], FORM_SUPER
        jne  .small_sprite
        shl  bx, 1                      ; Super sprites have 32 rows: pose * 512
        mov  ax, sprite_super_stand
        mov  dx, SPRITE_TALL            ; flags: 32 rows
.small_sprite:
        add  ax, bx                     ; AX = address of the sprite
        cmp  byte [hero_facing], FACING_LEFT
        jne  .face_done
        or   dx, SPRITE_MIRROR          ; facing left: mirrored
.face_done:
        mov  bx, [hero_x]               ; screen x = world x - camera x
        sub  bx, [camera_x]
        push bx
        mov  bx, [hero_y]               ; y = high byte of the 8.8 value
        mov  bl, bh
        mov  bh, 0
        push bx
        push ax                         ; sprite address
        push dx                         ; flags
        call DrawSprite

        cmp  byte [head_hit], 0         ; small yellow square at the top right
        je   .no_marker                 ; while Mario's head hits a block
        mov  ax, 300
        push ax
        mov  ax, 2
        push ax
        mov  ax, 8
        push ax
        push ax
        mov  ax, COLOUR_YELLOW
        push ax
        call FillRect
.no_marker:
        call CopyFrameToScreen          ; step 10: show the finished frame

                call CheckHeroPit
        cmp  ax, 0
        jne  .stopped

        call CheckHeroFlag
        cmp  ax, 0
        jne  .stopped

        cmp  byte [hp], 0
        je   .stopped
       cmp  byte [key_table+KEY_ESC], 0
       je   .game_loop

        jmp  .leave
.stopped:
        cmp  byte [key_table+KEY_ESC], 0
        je   .stopped                   ; freeze until Esc is pressed
.leave:
       call ExitToDos

; ---- 3. Module 1 procedures ---------------------------------------------

; Procedure: SetTextMode
; Purpose: Switch to 80x25 text mode.
SetTextMode:
       push ax
       push bp
       push si
       push di
       mov  ax, BIOS_TEXT_MODE
       int  10h
       pop  di
       pop  si
       pop  bp
       pop  ax
       ret

; Procedure: PrintString
; Input: [bp+4] = address of text ending with '$'
PrintString:
       push bp
       mov  bp, sp
       push ax
       push dx
       mov  dx, [bp+4]
       mov  ah, DOS_PRINT_STRING
       int  21h
       pop  dx
       pop  ax
       pop  bp
       ret  2

; Procedure: ExitToDos
; Purpose: Return control to DOS.
; --------------------------------------------------------------------------
; Procedure : ExitToDos
; Purpose   : End the program and return to the DOS prompt (INT 21h, 4Ch).
;             Every exit path of the game ends here.
; Inputs    : none
; Outputs   : never returns
; Registers : AX changed (program ends, so it does not matter)
; Note      : Restores the keyboard vector (Module 7) and text mode.
;             The timer vector and PIT rate are also restored here.
; --------------------------------------------------------------------------
ExitToDos:
       call RemoveTimerHandler
       call RemoveKeyboardHandler      ; give INT 09h back to the BIOS
       call SetTextMode                ; always leave in text mode
       mov  ah, DOS_EXIT_FUNCTION
       mov  al, 0
       int  21h

; ---- 4. Code files -------------------------------------------------------
%include "video.asm"
%include "map.asm"
%include "framebuf.asm"
%include "camera.asm"
%include "keyboard.asm"
%include "timer.asm"
%include "blocks.asm"
%include "states.asm"
%include "screens.asm"
%include "exit.asm"
%include "sprites.asm"
%include "font.asm"
%include "score.asm"
%include "hud.asm"
%include "hero.asm"
%include "collision.asm"
%include "enemies.asm"
%include "sequences.asm"

; ---- 5. Data files -------------------------------------------------------
%include "tile_data.asm"
%include "level_data.asm"
%include "sprite_data.asm"
%include "data_engine.asm"
%include "data_game.asm"
