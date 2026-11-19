; map.asm - owner: Yahya Masood - stub, filled in later
; ==========================================================================
; FILE    : src/map.asm
; OWNER   : Yahya Masood (Module 3)
; PURPOSE : Level map procedures: DrawTile, DrawMap, GetTile, ResetMap.
;           Map data (original_map, working_map) is in level_data.asm and
;           the tile colours are in tile_data.asm.
;           Parameters go on the stack (pushed left to right).
;           Only basic 8086 instructions are used.
; ==========================================================================

; --------------------------------------------------------------------------
; Procedure : DrawTile
; Purpose   : Draw one 16 x 16 tile as a solid square. The colour comes from
;             tile_colours, indexed by the tile code.
; Inputs    : push x, push y, push tile_code (0 to 12)
;             [bp+8] = x   [bp+6] = y   [bp+4] = tile code
; Outputs   : none
; Registers : none changed (AX, BX, CX, BP saved and restored)
; Note      : "ret 6" removes the 3 parameter words from the stack.
; --------------------------------------------------------------------------
DrawTile:
        push bp
        mov  bp, sp
        push ax
        push bx
        push cx

        mov  bx, [bp+4]                 ; BX = tile code
        mov  cl, [tile_colours+bx]      ; CL = colour of this tile code
        mov  ch, 0                      ; CX = colour

        mov  ax, [bp+8]                 ; FillRect parameter 1: x
        push ax
        mov  ax, [bp+6]                 ; FillRect parameter 2: y
        push ax
        mov  ax, TILE_SIZE              ; FillRect parameter 3: width = 16
        push ax
        push ax                         ; FillRect parameter 4: height = 16
        push cx                         ; FillRect parameter 5: colour
        call FillRect

        pop  cx
        pop  bx
        pop  ax
        pop  bp
        ret  6

; --------------------------------------------------------------------------
; Procedure : DrawMap
; Purpose   : Draw 20 columns x 12 rows of the working map, starting at the
;             given map column. Tile (0,0) of the window is drawn at the top
;             left corner of the screen. No pixel scrolling (Module 6).
; Inputs    : push first_column (0 to 40)
;             [bp+4] = first map column to draw
; Outputs   : none
; Registers : none changed (AX, BX, CX, DX, SI, DI, BP saved and restored)
; Logic     : SI = address of the current tile in working_map
;             BX = screen x, DX = screen y
;             CX = columns left in this row, DI = rows left
; Note      : "ret 2" removes the 1 parameter word from the stack.
; --------------------------------------------------------------------------
DrawMap:
        push bp
        mov  bp, sp
        push ax
        push bx
        push cx
        push dx
        push si
        push di

        mov  si, working_map            ; SI = start of row 0 of the map
        add  si, [bp+4]                 ; SI = tile (first_column, row 0)
        mov  dx, 0                      ; DX = screen y of the first row
        mov  di, LEVEL_ROWS             ; DI = rows left (12)
.row_loop:
        mov  bx, 0                      ; BX = screen x of the first column
        mov  cx, VISIBLE_COLS           ; CX = columns left (20)
.col_loop:
        push bx                         ; DrawTile parameter 1: x
        push dx                         ; DrawTile parameter 2: y
        mov  al, [si]                   ; AL = tile code from the map
        mov  ah, 0
        push ax                         ; DrawTile parameter 3: tile code
        call DrawTile
        inc  si                         ; next tile in this map row
        add  bx, TILE_SIZE              ; next screen x (16 pixels right)
        dec  cx
        jnz  .col_loop
        add  si, LEVEL_COLS-VISIBLE_COLS ; skip the 40 columns not drawn
        add  dx, TILE_SIZE              ; next screen y (16 pixels down)
        dec  di
        jnz  .row_loop

        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        pop  bp
        ret  2

; --------------------------------------------------------------------------
; Procedure : GetTile
; Purpose   : Convert a pixel position in the world to the tile code of the
;             working map: column = px / 16, row = py / 16,
;             tile = working_map[row*60 + column].
;             A position outside the map gives TILE_SKY.
; Inputs    : push px, push py   (world pixel position)
;             [bp+6] = px   [bp+4] = py
; Outputs   : AX = tile code (AH = 0)
; Registers : only AX changed (BX, CX, BP saved and restored)
; Note      : "ret 4" removes the 2 parameter words from the stack.
; --------------------------------------------------------------------------
GetTile:
        push bp
        mov  bp, sp
        push bx
        push cx

        mov  ax, [bp+6]                 ; AX = px
        shr  ax, 1                      ; divide by 16 = shift right 4 times
        shr  ax, 1
        shr  ax, 1
        shr  ax, 1                      ; AX = column
        mov  bx, [bp+4]                 ; BX = py
        shr  bx, 1
        shr  bx, 1
        shr  bx, 1
        shr  bx, 1                      ; BX = row

        cmp  ax, LEVEL_COLS             ; column >= 60 ? (unsigned compare)
        jae  .outside
        cmp  bx, LEVEL_ROWS             ; row >= 12 ?
        jae  .outside

        mov  cx, ax                     ; CX = column
        mov  ax, bx                     ; AL = row (0 to 11)
        mov  bl, LEVEL_COLS             ; BL = 60
        mul  bl                         ; AX = row * 60
        add  ax, cx                     ; AX = row*60 + column
        mov  bx, ax                     ; BX = offset into the map
        mov  al, [working_map+bx]       ; AL = tile code
        mov  ah, 0
        jmp  .done

.outside:
        mov  ax, TILE_SKY               ; outside the map counts as sky
.done:
        pop  cx
        pop  bx
        pop  bp
        ret  4

; --------------------------------------------------------------------------
; Procedure : ResetMap
; Purpose   : Copy original_map into working_map with one block move
;             (REP MOVSB). Undoes every change made to the working map.
; Inputs    : none. MOVSB copies from DS:SI to ES:DI, so ES is temporarily
;             set equal to DS (the segment that holds both maps).
; Outputs   : none (working_map equals original_map)
; Registers : none changed except the direction flag (CLD clears it).
;             CX, SI, DI and ES are saved and restored.
; --------------------------------------------------------------------------
ResetMap:
        push cx
        push si
        push di
        push es

        push ds
        pop  es
        cld

        mov  si, original_map
        mov  di, working_map
        mov  cx, LEVEL_SIZE
        rep  movsb

        pop  es
        pop  di
        pop  si
        pop  cx
        ret