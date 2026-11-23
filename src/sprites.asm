; ==========================================================================
; FILE    : src/sprites.asm
; OWNER   : Sami Ahsan (Module 4)
; PURPOSE : DrawSprite: draw a 16 x 16 or 16 x 32 sprite from sprite_data.asm.
;           Parameters go on the stack (pushed left to right).
;           Only basic 8086 instructions are used.
; CLIPPING: every pixel is drawn with PutPixel (Module 2). PutPixel ignores
;           any pixel outside the 320 x 200 screen, so a sprite that is
;           partly off the left, right, top or bottom edge is cut safely
;           and no memory outside the screen is ever written. A negative
;           x or y is a very large unsigned number, so PutPixel rejects it.
;           (If PutPixel is changed later, it must keep this check.)
; ==========================================================================

; --------------------------------------------------------------------------
; Procedure : DrawSprite
; Purpose   : Draw one sprite with its top-left corner at screen (x, y).
;             Colour 0 is transparent and is skipped.
; Inputs    : push x, push y, push address, push flags
;             [bp+10] = x (signed, may be negative or above 319)
;             [bp+8]  = y (signed, may be negative or above 199)
;             [bp+6]  = address of the sprite's first byte (sprite_xxx label)
;             [bp+4]  = flags, add together any of:
;                         SPRITE_MIRROR  draw flipped left-right
;                         SPRITE_HALF    draw only every second pixel
;                                        (half-transparent, for blinking)
;                         SPRITE_TALL    sprite has 32 rows (Super Mario)
;                       use 0 for a normal 16 x 16 sprite.
; Outputs   : none
; Registers : none changed (AX, BX, CX, DX, SI, DI, BP saved and restored)
; Logic     : SI = address of the current source row (16 bytes per row)
;             DX = screen y of the current row, DI = rows left
;             CX = column number 0 to 15 inside the row
;             BX = source column (CX, or 15 - CX when mirrored)
; Note      : "ret 8" removes the 4 parameter words from the stack.
;             Blinking as in PDF 5.7 ("only on alternate frames") can also be
;             done by the caller: call DrawSprite on one frame and skip the
;             call on the next.
; --------------------------------------------------------------------------
DrawSprite:
        push bp
        mov  bp, sp
        push ax
        push bx
        push cx
        push dx
        push si
        push di

        mov  si, [bp+6]                 ; SI = start of the sprite data
        mov  dx, [bp+8]                 ; DX = screen y of the first row
        mov  di, SMALL_HEIGHT           ; DI = rows left: 16 for a small sprite
        test word [bp+4], SPRITE_TALL   ; is the tall flag set?
        jz   .row_loop                  ; no: keep 16 rows
        mov  di, SUPER_HEIGHT           ; yes: 32 rows

.row_loop:
        mov  cx, 0                      ; start at column 0 of this row

.col_loop:
        mov  bx, cx                     ; BX = source column (normal)
        test word [bp+4], SPRITE_MIRROR ; is the mirror flag set?
        jz   .read_pixel                ; no: use the column as it is
        mov  bx, TILE_SIZE-1            ; yes: source column = 15 - column
        sub  bx, cx

.read_pixel:
        mov  al, [si+bx]                ; AL = colour of this pixel
        cmp  al, TRANSPARENT_COLOUR     ; colour 0 is never drawn
        je   .next_pixel

        test word [bp+4], SPRITE_HALF   ; is the half-transparent flag set?
        jz   .draw_pixel                ; no: draw the pixel
        mov  bx, cx                     ; yes: draw only when (column + rows
        add  bx, di                     ; left) is even, which gives a
        test bx, 1                      ; chessboard pattern of pixels
        jnz  .next_pixel                ; odd: skip this pixel

.draw_pixel:
        mov  bx, [bp+10]                ; BX = x of the sprite
        add  bx, cx                     ; BX = screen x of this pixel
        push bx                         ; PutPixel parameter 1: x
        push dx                         ; PutPixel parameter 2: y
        mov  ah, 0                      ; AX = colour
        push ax                         ; PutPixel parameter 3: colour
        call PutPixel                   ; PutPixel clips and draws the pixel

.next_pixel:
        inc  cx                         ; next column
        cmp  cx, TILE_SIZE              ; all 16 columns done?
        jb   .col_loop

        add  si, TILE_SIZE              ; next source row (16 bytes further)
        inc  dx                         ; next screen row
        dec  di                         ; one row less to do
        jnz  .row_loop

        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        pop  bp
        ret  8