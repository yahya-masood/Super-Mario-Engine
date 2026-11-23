; framebuf.asm - owner: Yahya Masood - stub, filled in later
; ==========================================================================
; FILE    : src/framebuf.asm
; OWNER   : Yahya Masood (Module 5)
; PURPOSE : Off-screen frame buffer. All drawing (PutPixel) goes into a
;           64000 byte buffer in its own memory segment. At the end of a
;           frame the whole buffer is copied to video memory at once.
; MEMORY  : A .COM program owns one 64 KB segment, which has no room for a
;           64000 byte buffer. InitFrameBuffer asks DOS (INT 21h) for a
;           second memory block of 64000 bytes and stores its segment
;           number in framebuffer_segment (variable in data_engine.asm).
;           DOS frees this block by itself when the program ends.
; ==========================================================================

; ---- Constants used only in this file ------------------------------------
DOS_RESIZE_BLOCK        equ 4Ah         ; INT 21h: change size of a block
DOS_ALLOCATE_BLOCK      equ 48h         ; INT 21h: get a new block of memory
PROGRAM_PARAGRAPHS      equ 1000h       ; 1000h paragraphs of 16 bytes = 64 KB
FRAMEBUFFER_PARAGRAPHS  equ FRAMEBUFFER_SIZE/16     ; 64000 / 16 = 4000
FRAMEBUFFER_WORDS       equ FRAMEBUFFER_SIZE/2      ; 64000 / 2 = 32000

; --------------------------------------------------------------------------
; Procedure : InitFrameBuffer
; Purpose   : Reserve 64000 bytes of memory for the frame buffer.
;             Step 1: shrink our own memory block to 64 KB (DOS gives a .COM
;                     program ALL free memory, so nothing is left to get).
;             Step 2: allocate a new block of 4000 paragraphs.
;             If either step fails, a message is printed and the program
;             returns to DOS (ExitToDos), so this procedure only returns
;             when the buffer exists.
; Inputs    : none (call it BEFORE SetVideoMode13 and before any drawing)
; Outputs   : framebuffer_segment = segment of the new buffer
; Registers : none changed (AX, BX, ES saved and restored)
; --------------------------------------------------------------------------
InitFrameBuffer:
        push ax
        push bx
        push es

        push cs                         ; ES = our own segment, the block
        pop  es                         ; that DOS must shrink
        mov  bx, PROGRAM_PARAGRAPHS     ; new size of our block: 64 KB
        mov  ah, DOS_RESIZE_BLOCK
        int  21h
        jc   .failed                    ; carry flag set = DOS reported error

        mov  bx, FRAMEBUFFER_PARAGRAPHS ; ask for 4000 paragraphs
        mov  ah, DOS_ALLOCATE_BLOCK
        int  21h
        jc   .failed                    ; carry flag set = not enough memory
        mov  [framebuffer_segment], ax  ; DOS returns the new segment in AX

        pop  es
        pop  bx
        pop  ax
        ret

.failed:
        mov  ax, msg_no_memory          ; text ending in '$'
        push ax
        call PrintString
        call ExitToDos                  ; never returns

; --------------------------------------------------------------------------
; Procedure : ClearFrameBuffer
; Purpose   : Fill the whole frame buffer with colour 0 (black) using one
;             block store (REP STOSW). Called at the start of every frame.
;             STOSW stores AX at [ES:DI] and then adds 2 to DI (direction
;             flag = 0). REP repeats it CX times: 32000 words = 64000 bytes.
; Inputs    : none (framebuffer_segment must be set)
; Outputs   : none (every byte of the buffer is 0)
; Registers : none changed except the direction flag (CLD clears it).
;             AX, CX, DI, ES are saved and restored.
; --------------------------------------------------------------------------
ClearFrameBuffer:
        push ax
        push cx
        push di
        push es

        mov  ax, [framebuffer_segment]  ; ES = segment of the frame buffer
        mov  es, ax
        cld                             ; direction flag = 0: DI goes up
        mov  di, 0                      ; start at the first byte
        mov  cx, FRAMEBUFFER_WORDS      ; number of words to store (32000)
        mov  ax, 0                      ; the word to store: two black pixels
        rep  stosw                      ; store AX at [ES:DI], CX times

        pop  es
        pop  di
        pop  cx
        pop  ax
        ret

; --------------------------------------------------------------------------
; Procedure : CopyFrameToScreen
; Purpose   : Copy the whole frame buffer to video memory with one block
;             move (REP MOVSW). MOVSW copies one word from [DS:SI] to
;             [ES:DI] and adds 2 to both SI and DI (direction flag = 0).
;             So DS is set to the buffer segment and ES to video memory.
; Inputs    : none (framebuffer_segment must be set)
; Outputs   : none (the picture appears on the screen)
; Registers : none changed except the direction flag (CLD clears it).
;             AX, CX, SI, DI, DS, ES are saved and restored.
; Note      : DS no longer points at our variables while the copy runs, so
;             framebuffer_segment is read BEFORE DS is changed. Interrupt
;             handlers (Modules 7 and 8) must therefore set their own DS.
; --------------------------------------------------------------------------
CopyFrameToScreen:
        push ax
        push cx
        push si
        push di
        push ds
        push es

        mov  ax, [framebuffer_segment]  ; read the variable while DS is ours
        mov  ds, ax                     ; DS:SI = source = frame buffer
        mov  ax, VIDEO_SEGMENT
        mov  es, ax                     ; ES:DI = destination = video memory
        cld                             ; direction flag = 0: SI, DI go up
        mov  si, 0
        mov  di, 0
        mov  cx, FRAMEBUFFER_WORDS      ; number of words to copy (32000)
        rep  movsw                      ; copy CX words from [DS:SI] to [ES:DI]

        pop  es
        pop  ds
        pop  di
        pop  si
        pop  cx
        pop  ax
        ret