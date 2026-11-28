; ==========================================================================
; FILE    : src/video.asm
; OWNER   : Yahya Masood (Module 2, changed in Module 5)
; PURPOSE : VGA Mode 13h setup, PutPixel, FillRect and a colour test screen.
;           Mode 13h: 320x200 pixels, 1 byte per pixel, segment 0A000h.
;           Offset of pixel (x, y) = y*320 + x = (y*256) + (y*64) + x.
; MODULE 5: PutPixel now draws into the OFF-SCREEN FRAME BUFFER (segment in
;           framebuffer_segment), not into video memory. Nothing appears on
;           the screen until CopyFrameToScreen (framebuf.asm) is called.
;           InitFrameBuffer must have been called before any drawing.
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
; Purpose   : Draw one pixel of the given colour at (x, y) in the frame
;             buffer. Pixels outside the screen are ignored (no memory
;             damage).
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

        mov  ax, [framebuffer_segment]  ; ES = segment of the frame buffer
        mov  es, ax                     ; (a segment cannot be loaded directly)
        mov  al, [bp+4]                 ; AL = colour
        mov  [es:bx], al                ; write the pixel into the buffer

.done:
        pop  es
        pop  dx
        pop  bx
        pop  ax
        pop  bp
        ret  6

; --------------------------------------------------------------------------
; Procedure : FillRect
; Purpose   : Fill a rectangle with one colour in the frame buffer.
;             The rectangle is first CLIPPED to the screen (x and y may be
;             negative or too big), then every row is filled with ONE
;             REP STOSB instead of one PutPixel call per pixel. This is
;             about 40 times faster, which the game needs: DrawMap draws
;             the whole level with it in every frame.
; Inputs    : push x, push y, push width, push height, push colour
;             [bp+12] = x   [bp+10] = y   [bp+8] = width
;             [bp+6]  = height            [bp+4]  = colour
; Outputs   : none
; Registers : none changed except the direction flag (CLD clears it).
;             AX, BX, CX, DX, SI, DI, ES are saved and restored.
; Logic     : BX = x, CX = width, DX = y, SI = height (after clipping)
;             DI = offset of the first pixel = y*320 + x = y*256 + y*64 + x
;             STOSB stores AL at [ES:DI] and adds 1 to DI (direction flag
;             = 0); REP repeats it CX times, so one row is filled.
; Note      : "ret 10" removes the 5 parameter words from the stack.
; --------------------------------------------------------------------------
FillRect:
        push bp
        mov  bp, sp
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        push es

        mov  bx, [bp+12]                ; BX = x
        mov  cx, [bp+8]                 ; CX = width
        cmp  bx, 0
        jge  .left_ok                   ; x >= 0 (signed compare)
        add  cx, bx                     ; x is negative: cut the width
        mov  bx, 0                      ; and start at the left edge
.left_ok:
        mov  ax, SCREEN_WIDTH
        sub  ax, bx                     ; AX = pixels from x to the right edge
        cmp  cx, ax
        jle  .width_ok
        mov  cx, ax                     ; too wide: cut at the right edge
.width_ok:
        cmp  cx, 0
        jle  .done                      ; nothing of it is on the screen

        mov  dx, [bp+10]                ; DX = y
        mov  si, [bp+6]                 ; SI = height = rows to fill
        cmp  dx, 0
        jge  .top_ok
        add  si, dx                     ; y is negative: cut the height
        mov  dx, 0                      ; and start at the top edge
.top_ok:
        mov  ax, SCREEN_HEIGHT
        sub  ax, dx                     ; AX = rows from y to the bottom edge
        cmp  si, ax
        jle  .height_ok
        mov  si, ax                     ; too high: cut at the bottom edge
.height_ok:
        cmp  si, 0
        jle  .done                      ; nothing of it is on the screen

        mov  di, dx                     ; DI = y
        shl  di, 1                      ; y * 2
        shl  di, 1                      ; y * 4
        shl  di, 1                      ; y * 8
        shl  di, 1                      ; y * 16
        shl  di, 1                      ; y * 32
        shl  di, 1                      ; y * 64
        mov  ax, dx
        shl  ax, 1                      ; y * 2
        shl  ax, 1                      ; y * 4
        shl  ax, 1                      ; y * 8
        shl  ax, 1                      ; y * 16
        shl  ax, 1                      ; y * 32
        shl  ax, 1                      ; y * 64
        shl  ax, 1                      ; y * 128
        shl  ax, 1                      ; y * 256
        add  di, ax                     ; y*64 + y*256 = y * 320
        add  di, bx                     ; DI = y*320 + x = first pixel

        mov  ax, [framebuffer_segment]  ; ES = segment of the frame buffer
        mov  es, ax
        mov  al, [bp+4]                 ; AL = colour
        cld                             ; direction flag = 0: DI goes up
        mov  dx, cx                     ; DX = width (CX is used by REP)
.row_loop:
        push di                         ; remember the start of this row
        mov  cx, dx                     ; CX = pixels in the row
        rep  stosb                      ; fill the row
        pop  di
        add  di, SCREEN_WIDTH           ; next row: 320 bytes further
        dec  si
        jnz  .row_loop

.done:
        pop  es
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
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