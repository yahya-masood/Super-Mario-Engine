; ==========================================================================
; FILE    : src/video.asm
; OWNER   : Yahya Masood (Module 2)
; PURPOSE : VGA Mode 13h setup, PutPixel, FillRect and a colour test screen.
;           Mode 13h: 320x200 pixels, 1 byte per pixel, segment 0A000h.
;           Offset of pixel (x, y) = y*320 + x = (y*256) + (y*64) + x.
; NOTE    : SetTextMode is in mario.asm (Module 1), not repeated here.
;           Parameters go on the stack (pushed left to right).
;           Only basic 8086 instructions are used: no immediate PUSH, no
;           push from memory, and shifts are done one bit at a time.
; ==========================================================================

; --------------------------------------------------------------------------
; Procedure : SetVideoMode13
; Purpose   : Switch to VGA graphics mode 13h (320x200, 256 colours).
; Inputs    : none
; Outputs   : none (screen is in graphics mode and cleared)
; Registers : none changed (AX, BP, SI, DI saved and restored)
; --------------------------------------------------------------------------
SetVideoMode13:
        push ax
        push bp                         ; same safety saves as SetTextMode
        push si
        push di
        mov  ax, BIOS_VGA_MODE          ; AH = 00h set mode, AL = 13h
        int  10h                        ; BIOS video service
        pop  di
        pop  si
        pop  bp
        pop  ax
        ret

; --------------------------------------------------------------------------
; Procedure : PutPixel
; Purpose   : Draw one pixel of the given colour at (x, y).
;             Pixels outside the screen are ignored (no memory damage).
; Inputs    : push x, push y, push colour (only the low byte is used)
;             [bp+8] = x   [bp+6] = y   [bp+4] = colour
; Outputs   : none
; Registers : none changed (AX, BX, DX, ES, BP saved and restored)
; Note      : "ret 6" removes the 3 parameter words from the stack.
; --------------------------------------------------------------------------
PutPixel:
        push bp
        mov  bp, sp
        push ax
        push bx
        push dx
        push es

        mov  ax, [bp+8]                 ; AX = x
        mov  bx, [bp+6]                 ; BX = y
        cmp  ax, SCREEN_WIDTH           ; x >= 320 ? (unsigned compare)
        jae  .done                      ; yes: outside the screen, skip
        cmp  bx, SCREEN_HEIGHT          ; y >= 200 ?
        jae  .done                      ; yes: outside the screen, skip

        mov  dx, bx                     ; DX = y (copy)
        shl  dx, 1                      ; DX = y * 2
        shl  dx, 1                      ; DX = y * 4
        shl  dx, 1                      ; DX = y * 8
        shl  dx, 1                      ; DX = y * 16
        shl  dx, 1                      ; DX = y * 32
        shl  dx, 1                      ; DX = y * 64   (6 shifts)

        shl  bx, 1                      ; BX = y * 2
        shl  bx, 1                      ; BX = y * 4
        shl  bx, 1                      ; BX = y * 8
        shl  bx, 1                      ; BX = y * 16
        shl  bx, 1                      ; BX = y * 32
        shl  bx, 1                      ; BX = y * 64
        shl  bx, 1                      ; BX = y * 128
        shl  bx, 1                      ; BX = y * 256  (8 shifts)

        add  bx, dx                     ; BX = y*256 + y*64 = y * 320
        add  bx, ax                     ; BX = y*320 + x = pixel offset

        mov  ax, VIDEO_SEGMENT          ; ES = video memory segment
        mov  es, ax                     ; (a segment cannot be loaded directly)
        mov  al, [bp+4]                 ; AL = colour
        mov  [es:bx], al                ; write the pixel

.done:
        pop  es
        pop  dx
        pop  bx
        pop  ax
        pop  bp
        ret  6

; --------------------------------------------------------------------------
; Procedure : FillRect
; Purpose   : Fill a rectangle with one colour (calls PutPixel per pixel).
; Inputs    : push x, push y, push width, push height, push colour
;             [bp+12] = x   [bp+10] = y   [bp+8] = width
;             [bp+6]  = height            [bp+4]  = colour
; Outputs   : none
; Registers : none changed (BX, CX, DX, SI, BP saved and restored)
; Logic     : DX = current row y, BX = current x, SI = colour,
;             CX = rows left, then columns left. The rows-left count is
;             saved on the stack while CX is reused for the columns.
; Note      : "ret 10" removes the 5 parameter words from the stack.
; --------------------------------------------------------------------------
FillRect:
        push bp
        mov  bp, sp
        push bx
        push cx
        push dx
        push si

        mov  dx, [bp+10]                ; DX = y of the current row
        mov  cx, [bp+6]                 ; CX = rows left (height)
        mov  si, [bp+4]                 ; SI = colour
.row_loop:
        cmp  cx, 0                      ; no rows left?
        je   .done
        push cx                         ; save rows left
        mov  bx, [bp+12]                ; BX = x of the first pixel in the row
        mov  cx, [bp+8]                 ; CX = columns left (width)
.col_loop:
        cmp  cx, 0                      ; row finished?
        je   .row_done
        push bx                         ; parameter x
        push dx                         ; parameter y
        push si                         ; parameter colour
        call PutPixel                   ; PutPixel removes its 3 parameters
        inc  bx                         ; next pixel to the right
        dec  cx
        jmp  .col_loop
.row_done:
        pop  cx                         ; restore rows left
        inc  dx                         ; next row down
        dec  cx
        jmp  .row_loop

.done:
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  bp
        ret  10

; --------------------------------------------------------------------------
; Procedure : DrawTestScreen
; Purpose   : Module 2 test screen: shows all 12 game colours as a grid of
;             4 columns x 3 rows. Each tile is 80 wide and 64 high, so the
;             grid fills 320 x 192 pixels (the bottom 8 rows stay black).
;             Every FillRect call below pushes: x, y, width, height, colour.
;             Numbers are loaded with "mov ax, value" and then "push ax",
;             because the 8086 cannot push a number directly.
; Inputs    : none (screen must already be in mode 13h)
; Outputs   : none
; Registers : none changed (AX saved and restored)
; --------------------------------------------------------------------------
DrawTestScreen:
        push ax

        ; ---- row 1 (y = 0) ------------------------------------------------
        mov  ax, 0                      ; tile 1: sky
        push ax                         ;   x
        mov  ax, 0
        push ax                         ;   y
        mov  ax, 80
        push ax                         ;   width
        mov  ax, 64
        push ax                         ;   height
        mov  ax, COLOUR_SKY
        push ax                         ;   colour
        call FillRect

        mov  ax, 80                     ; tile 2: green
        push ax
        mov  ax, 0
        push ax
        mov  ax, 80
        push ax
        mov  ax, 64
        push ax
        mov  ax, COLOUR_GREEN
        push ax
        call FillRect

        mov  ax, 160                    ; tile 3: brown
        push ax
        mov  ax, 0
        push ax
        mov  ax, 80
        push ax
        mov  ax, 64
        push ax
        mov  ax, COLOUR_BROWN
        push ax
        call FillRect

        mov  ax, 240                    ; tile 4: pipe green
        push ax
        mov  ax, 0
        push ax
        mov  ax, 80
        push ax
        mov  ax, 64
        push ax
        mov  ax, COLOUR_PIPE_GREEN
        push ax
        call FillRect

        ; ---- row 2 (y = 64) -----------------------------------------------
        mov  ax, 0                      ; tile 5: red
        push ax
        mov  ax, 64
        push ax
        mov  ax, 80
        push ax
        mov  ax, 64
        push ax
        mov  ax, COLOUR_RED
        push ax
        call FillRect

        mov  ax, 80                     ; tile 6: black
        push ax
        mov  ax, 64
        push ax
        mov  ax, 80
        push ax
        mov  ax, 64
        push ax
        mov  ax, COLOUR_BLACK
        push ax
        call FillRect

        mov  ax, 160                    ; tile 7: yellow
        push ax
        mov  ax, 64
        push ax
        mov  ax, 80
        push ax
        mov  ax, 64
        push ax
        mov  ax, COLOUR_YELLOW
        push ax
        call FillRect

        mov  ax, 240                    ; tile 8: light red
        push ax
        mov  ax, 64
        push ax
        mov  ax, 80
        push ax
        mov  ax, 64
        push ax
        mov  ax, COLOUR_LIGHT_RED
        push ax
        call FillRect

        ; ---- row 3 (y = 128) ----------------------------------------------
        mov  ax, 0                      ; tile 9: blue
        push ax
        mov  ax, 128
        push ax
        mov  ax, 80
        push ax
        mov  ax, 64
        push ax
        mov  ax, COLOUR_BLUE
        push ax
        call FillRect

        mov  ax, 80                     ; tile 10: light grey
        push ax
        mov  ax, 128
        push ax
        mov  ax, 80
        push ax
        mov  ax, 64
        push ax
        mov  ax, COLOUR_LIGHT_GREY
        push ax
        call FillRect

        mov  ax, 160                    ; tile 11: dark grey
        push ax
        mov  ax, 128
        push ax
        mov  ax, 80
        push ax
        mov  ax, 64
        push ax
        mov  ax, COLOUR_DARK_GREY
        push ax
        call FillRect

        mov  ax, 240                    ; tile 12: white
        push ax
        mov  ax, 128
        push ax
        mov  ax, 80
        push ax
        mov  ax, 64
        push ax
        mov  ax, COLOUR_WHITE
        push ax
        call FillRect

        pop  ax
        ret