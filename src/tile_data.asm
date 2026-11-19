; tile_data.asm - owner: Yahya Masood - stub, filled in later
; ==========================================================================
; FILE    : src/tile_data.asm
; OWNER   : Yahya Masood (Module 3)
; PURPOSE : Colour of each tile code (Appendix A.2). DrawTile uses the tile
;           code as an index into this table (one byte per code).
; NOTE    : Flat colours for now. Detailed tile artwork is added later.
; ==========================================================================

tile_colours:
        db COLOUR_SKY                   ; 0  sky
        db COLOUR_BROWN                 ; 1  ground
        db COLOUR_RED                   ; 2  brick
        db COLOUR_YELLOW                ; 3  "?" block with coin
        db COLOUR_YELLOW                ; 4  "?" block with mushroom
        db COLOUR_DARK_GREY             ; 5  empty block
        db COLOUR_PIPE_GREEN            ; 6  pipe top-left
        db COLOUR_PIPE_GREEN            ; 7  pipe top-right
        db COLOUR_PIPE_GREEN            ; 8  pipe body-left
        db COLOUR_PIPE_GREEN            ; 9  pipe body-right
        db COLOUR_LIGHT_GREY            ; 10 stair block
        db COLOUR_WHITE                 ; 11 coin
        db COLOUR_GREEN                 ; 12 flag pole