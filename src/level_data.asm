; level_data.asm - owner: Yahya Masood - stub, filled in later
; ==========================================================================
; FILE    : src/level_data.asm
; OWNER   : Yahya Masood (Module 3)
; PURPOSE : The level map: 60 columns x 12 rows, one byte per tile.
;           original_map : never changed (the master copy)
;           working_map  : the copy the game changes (blocks hit, coins taken)
;           ResetMap copies original_map into working_map.
; LAYOUT  : tile at (column, row) is at offset  row*60 + column.
;           Each source line below holds 20 columns, three lines per row.
; TILE CODES (Appendix A.2):
;   0 sky          1 ground        2 brick        3 "?" coin     4 "?" mushroom
;   5 empty block  6 pipe top-L    7 pipe top-R   8 pipe body-L  9 pipe body-R
;   10 stair block 11 coin         12 flag pole
; ==========================================================================

original_map:
        ; ---- row 0 : HUD strip (sky tiles, the HUD is drawn over it later) --
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0         ; columns 0-19
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0         ; columns 20-39
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0         ; columns 40-59
        ; ---- row 1 --------------------------------------------------------
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        ; ---- row 2 : top of the flag pole (column 56) ---------------------
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,12,0,0,0
        ; ---- row 3 --------------------------------------------------------
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,12,0,0,0
        ; ---- row 4 --------------------------------------------------------
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,12,0,0,0
        ; ---- row 5 --------------------------------------------------------
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,12,0,0,0
        ; ---- row 6 : "?" blocks, brick groups, top stair, flag pole -------
        db 0,0,0,0,0,0,0,0,4,0,0,0,2,2,2,3,0,0,0,0         ; ? mush col 8, bricks 12-14, ? coin col 15
        db 0,0,0,0,0,0,0,0,0,0,0,3,2,2,2,3,0,0,0,0         ; ? coin col 31, bricks 32-34, ? coin col 35
        db 0,0,0,0,0,0,0,0,4,0,0,0,0,10,0,0,12,0,0,0       ; ? mush col 48, stair col 53, pole col 56
        ; ---- row 7 : coins, top of the 3-high pipe, stairs ----------------
        db 0,0,0,0,11,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0        ; coin col 4
        db 11,11,11,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,6,7      ; coins 20-22 (above pit), pipe top cols 38-39
        db 0,11,11,11,11,11,11,0,0,0,0,0,10,10,0,0,12,0,0,0 ; coins 41-46, stairs 52-53, pole
        ; ---- row 8 : top of the 2-high pipe, pipe body, stairs ------------
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db 0,0,0,0,0,0,6,7,0,0,0,0,0,0,0,0,0,0,8,9         ; pipe top cols 26-27, pipe body cols 38-39
        db 0,0,0,0,0,0,0,0,0,0,0,10,10,10,0,0,12,0,0,0     ; stairs 51-53, pole (lowest pole tile)
        ; ---- row 9 : the row Mario stands on ------------------------------
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db 0,0,0,0,0,0,8,9,0,0,0,0,0,0,0,0,0,0,8,9         ; pipe body cols 26-27 and 38-39
        db 0,0,0,0,0,0,0,0,0,0,10,10,10,10,0,0,10,0,0,0    ; stairs 50-53, pole base block col 56
        ; ---- row 10 : ground, pits at columns 20-22 and 44-46 -------------
        db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
        db 0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
        db 1,1,1,1,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1
        ; ---- row 11 : ground ----------------------------------------------
        db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
        db 0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
        db 1,1,1,1,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1

; The working copy: 720 zero bytes, filled by ResetMap before the game uses it.
working_map:
        times LEVEL_SIZE db 0