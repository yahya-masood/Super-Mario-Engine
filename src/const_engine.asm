
; ==========================================================================
; FILE    : src/const_engine.asm
; OWNER   : Yahya Masood (Module 1)
; PURPOSE : Named constants for screen, tiles, colours, keyboard and states.
; ==========================================================================

; ---- BIOS / DOS service numbers ------------------------------------------
BIOS_TEXT_MODE       equ 0003h
BIOS_VGA_MODE        equ 0013h
DOS_PRINT_STRING     equ 09h
DOS_EXIT_FUNCTION    equ 4Ch

; ---- Screen and video memory ---------------------------------------------
SCREEN_WIDTH         equ 320
SCREEN_HEIGHT        equ 200
VIDEO_SEGMENT        equ 0A000h
FRAMEBUFFER_SIZE     equ 64000
TRANSPARENT_COLOUR   equ 0

; ---- Tiles and level ------------------------------------------------------
TILE_SIZE            equ 16
TILE_SHIFT           equ 4
VISIBLE_COLS         equ 20
VISIBLE_ROWS         equ 12
VISIBLE_HEIGHT       equ 192
HUD_HEIGHT           equ 16
LEVEL_COLS           equ 60
LEVEL_ROWS           equ 12
LEVEL_SIZE           equ LEVEL_COLS*LEVEL_ROWS
LEVEL_WIDTH_PX       equ LEVEL_COLS*TILE_SIZE
CAMERA_MAX           equ LEVEL_WIDTH_PX-SCREEN_WIDTH
CAMERA_FOLLOW_X      equ 160
GROUND_TOP_Y         equ 160

; ---- Colours -------------------------------------------------------------
COLOUR_BLACK         equ 0
COLOUR_BLUE          equ 1
COLOUR_GREEN         equ 2
COLOUR_BROWN         equ 6
COLOUR_LIGHT_GREY    equ 7
COLOUR_DARK_GREY     equ 8
COLOUR_SKY           equ 9
COLOUR_PIPE_GREEN    equ 10
COLOUR_LIGHT_RED     equ 12
COLOUR_RED           equ 4
COLOUR_YELLOW        equ 14
COLOUR_WHITE         equ 15
COLOUR_HUD_BG        equ 0

; ---- Tile codes ----------------------------------------------------------
TILE_SKY             equ 0
TILE_GROUND          equ 1
TILE_BRICK           equ 2
TILE_QBLOCK_COIN     equ 3
TILE_QBLOCK_MUSH     equ 4
TILE_EMPTY_BLOCK     equ 5
TILE_PIPE_TOP_L      equ 6
TILE_PIPE_TOP_R      equ 7
TILE_PIPE_BODY_L     equ 8
TILE_PIPE_BODY_R     equ 9
TILE_STAIR           equ 10
TILE_COIN            equ 11
TILE_FLAG            equ 12

; ---- Keyboard scan codes -------------------------------------------------
KEY_ESC              equ 01h
KEY_ENTER            equ 1Ch
KEY_P                 equ 19h
KEY_LSHIFT            equ 2Ah
KEY_SPACE             equ 39h
KEY_UP                equ 48h
KEY_LEFT              equ 4Bh
KEY_RIGHT             equ 4Dh
KEY_DOWN              equ 50h
KEY_RELEASE_BIT       equ 80h
KEY_EXTENDED_PREFIX   equ 0E0h

; ---- Game states ---------------------------------------------------------
STATE_TITLE           equ 0
STATE_PLAYING         equ 1
STATE_PAUSED          equ 2
STATE_DYING            equ 3
STATE_LIFE_LOST        equ 4
STATE_WIN_SEQUENCE     equ 5
STATE_LEVEL_COMPLETE   equ 6
STATE_GAME_OVER        equ 7
STATE_EXIT             equ 8
STATE_COUNT            equ 9
