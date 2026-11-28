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
; Purpose   : Draw the visible part of the working map for a camera position.
;             First tile column = camera_x / 16 (shift right 4 times).
;             The whole picture is moved left by camera_x mod 16 pixels
;             (camera_x AND 15), so it scrolls one pixel at a time and not
;             one tile at a time. That is why 20 columns plus one partial
;             column are drawn (21). When camera_x mod 16 = 0, 20 are enough.
;             The sky is drawn first with ONE FillRect and the sky tiles are
;             skipped, so only the real tiles (ground, blocks, pipes ...) cost
;             time. Without this the game ran far too slowly.
; Inputs    : push camera_x (0 to 640)
;             [bp+4] = camera_x
; Outputs   : none
; Registers : none changed (AX, BX, CX, DX, SI, DI, BP saved and restored)
; Logic     : SI = address of the current tile in working_map
;             BX = screen x of the current tile. It starts at
;                  -(camera_x mod 16), so it can be negative. PutPixel
;                  ignores the pixels that are off the screen.
;             DX = screen y, CX = columns left, DI = rows left
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

        mov  ax, 0                      ; fill the whole visible area with the
        push ax                         ; sky colour first (one fast FillRect):
        push ax                         ; x = 0, y = 0,
        mov  ax, SCREEN_WIDTH
        push ax                         ; width = 320,
        mov  ax, VISIBLE_HEIGHT
        push ax                         ; height = 192,
        mov  al, [tile_colours+TILE_SKY]
        mov  ah, 0
        push ax                         ; colour of the sky tile
        call FillRect                   ; so the sky tiles need no drawing

        mov  ax, [bp+4]                 ; AX = camera_x
        shr  ax, 1                      ; divide by 16 = shift right 4 times
        shr  ax, 1
        shr  ax, 1
        shr  ax, 1                      ; AX = first map column to draw
        mov  si, working_map            ; SI = start of row 0 of the map
        add  si, ax                     ; SI = tile (first column, row 0)
        mov  dx, 0                      ; DX = screen y of the first row
        mov  di, LEVEL_ROWS             ; DI = rows left (12)
.row_loop:
        mov  bx, [bp+4]                 ; BX = camera_x
        and  bx, 15                     ; BX = camera_x mod 16
        neg  bx                         ; BX = screen x of the first tile
        mov  cx, VISIBLE_COLS           ; CX = columns left (20)
        test word [bp+4], 15            ; is camera_x mod 16 not zero?
        jz   .col_loop                  ; zero: 20 columns are enough
        inc  cx                         ; not zero: draw 1 extra column
.col_loop:
        mov  al, [si]                   ; AL = tile code from the map
        mov  ah, 0
        cmp  al, TILE_SKY               ; sky is already drawn: skip it
        je   .next_tile
        push bx                         ; DrawTile parameter 1: x
        push dx                         ; DrawTile parameter 2: y
        push ax                         ; DrawTile parameter 3: tile code
        call DrawTile
.next_tile:
        inc  si                         ; next tile in this map row
        add  bx, TILE_SIZE              ; next screen x (16 pixels right)
        dec  cx
        jnz  .col_loop
        add  si, LEVEL_COLS-VISIBLE_COLS ; go to the same column, next row
        test word [bp+4], 15            ; were 21 columns read?
        jz   .next_row
        dec  si                         ; yes: step back the extra column
.next_row:
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
        push es                         ; save the caller's ES

        push ds                         ; ES = DS (a segment register cannot
        pop  es                         ; be loaded directly from another)
        cld                             ; direction flag = 0: SI, DI go up
        mov  si, original_map           ; source
        mov  di, working_map            ; destination
        mov  cx, LEVEL_SIZE             ; number of bytes to copy (720)
        rep  movsb                      ; copy CX bytes from [SI] to [ES:DI]

        pop  es                         ; restore the caller's ES
        pop  di
        pop  si
        pop  cx
        ret