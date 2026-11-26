
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
        call InstallTimerHandler
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

        ; Module 8: start the game clock for the new life
        mov  word [time_left], 300
        mov  byte [ticks_this_second], 0
        mov  byte [clock_running], 1

.game_loop:
        call WaitForTick
        cmp  byte [key_table+KEY_ESC], 0
        je   .game_loop

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
