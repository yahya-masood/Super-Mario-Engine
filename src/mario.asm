
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
        call SetVideoMode13             ; Module 2: enter VGA mode 13h
        call ResetMap                   ; Module 3: restore original map
        mov  ax, 0                      ; first map column = 0
        push ax
        call DrawMap                    ; draw visible level window
        mov  ah, 0                      ; BIOS keyboard service: wait for key
        int  16h
        call ExitToDos                  ; restore text mode and exit

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
ExitToDos:
        
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
