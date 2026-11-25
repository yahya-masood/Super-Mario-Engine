; timer.asm - owner: Yahya Masood - stub, filled in later
; ==========================================================================
; FILE    : src/timer.asm
; OWNER   : Yahya Masood (Module 8)
; PURPOSE : Timer interrupt and game clock (PDF Module 8, Sections 4, 5.10).
;           - The timer chip is set to about 30 ticks per second, so one
;             game second is exactly TICKS_PER_SECOND ticks.
;           - We hook INT 1Ch, the "user timer tick". The BIOS timer routine
;             (INT 08h) calls INT 1Ch on every tick AND sends the
;             end-of-interrupt itself, so our routine must NOT send one.
;           - Our routine counts ticks (tick_counter) and, while
;             clock_running = 1, counts the game clock (time_left).
;           - The game loop calls WaitForTick, so the game speed comes from
;             the timer and not from a delay loop.
; NOTE    : DOS_GET_VECTOR and DOS_SET_VECTOR are defined in keyboard.asm,
;           which is included before this file.
;           old_timer_segment = 0 means "our routine is not installed".
; ==========================================================================

; ---- Constants used only in this file ------------------------------------
TIMER_INT           equ 1Ch             ; interrupt number of the timer hook
PIT_COMMAND_PORT    equ 43h             ; timer chip command port
PIT_CHANNEL0_PORT   equ 40h             ; timer chip channel 0 data port
PIT_MODE_COMMAND    equ 36h             ; channel 0, low byte then high byte,
                                        ; mode 3 (square wave), binary count
PIT_DIVISOR_GAME    equ 39773           ; 1193182 / 39773 = 29.9998 ticks/s
PIT_DIVISOR_DEFAULT equ 0               ; 0 means 65536 = 18.2 ticks/s (BIOS)

; --------------------------------------------------------------------------
; Procedure : InstallTimerHandler
; Purpose   : Save the old INT 1Ch address, make INT 1Ch run TimerHandler,
;             and speed the timer chip up to about 30 ticks per second.
;             Does nothing if it is already installed.
; Inputs    : none (DS must be our own segment, as always in a .COM)
; Outputs   : old_timer_segment : old_timer_offset = the old INT 1Ch address
; Registers : none changed (AX, BX, DX, ES saved and restored)
; --------------------------------------------------------------------------
InstallTimerHandler:
        push ax
        push bx
        push dx
        push es

        cmp  word [old_timer_segment], 0 ; already installed?
        jne  .done                      ; yes: do nothing

        mov  ah, DOS_GET_VECTOR         ; get the current INT 1Ch address
        mov  al, TIMER_INT
        int  21h                        ; DOS returns it in ES:BX
        mov  [old_timer_offset], bx     ; save the offset
        mov  [old_timer_segment], es    ; save the segment (next to the offset)

        mov  dx, TimerHandler           ; DS:DX = address of our routine
        mov  ah, DOS_SET_VECTOR         ; set INT 1Ch to our routine
        mov  al, TIMER_INT
        int  21h

        mov  ax, PIT_DIVISOR_GAME       ; about 30 ticks per second
        push ax
        call SetTimerRate

.done:
        pop  es
        pop  dx
        pop  bx
        pop  ax
        ret

; --------------------------------------------------------------------------
; Procedure : RemoveTimerHandler
; Purpose   : Give INT 1Ch back to the old routine and put the timer chip
;             back to the normal BIOS speed. Does nothing if our routine is
;             not installed. Called from ExitToDos, so it runs on every
;             exit path. The vector is restored FIRST, so that our routine
;             can never be called after the program has ended.
; Inputs    : none
; Outputs   : old_timer_segment = 0 (not installed any more)
; Registers : none changed (AX, DX saved and restored; DS is changed for
;             one instruction and put back)
; --------------------------------------------------------------------------
RemoveTimerHandler:
        push ax
        push dx

        mov  ax, [old_timer_segment]    ; AX = saved segment
        cmp  ax, 0                      ; 0 = we never installed our routine
        je   .done
        mov  dx, [old_timer_offset]     ; DX = saved offset

        push ds                         ; keep our own DS
        mov  ds, ax                     ; DS:DX = the old INT 1Ch routine
        mov  ah, DOS_SET_VECTOR
        mov  al, TIMER_INT
        int  21h                        ; INT 1Ch is the old routine again
        pop  ds                         ; our DS again

        mov  word [old_timer_segment], 0 ; mark: not installed

        mov  ax, PIT_DIVISOR_DEFAULT    ; back to 18.2 ticks per second
        push ax
        call SetTimerRate

.done:
        pop  dx
        pop  ax
        ret

; --------------------------------------------------------------------------
; Procedure : SetTimerRate
; Purpose   : Program channel 0 of the timer chip with a new divisor.
;             ticks per second = 1193182 / divisor (divisor 0 means 65536).
;             Interrupts are switched off while the three bytes are sent.
; Inputs    : push divisor
;             [bp+4] = divisor
; Outputs   : none
; Registers : none changed (AX, BP saved and restored; the flags, including
;             the interrupt flag, are restored by POPF)
; Note      : "ret 2" removes the 1 parameter word from the stack.
; --------------------------------------------------------------------------
SetTimerRate:
        push bp
        mov  bp, sp
        push ax
        pushf                           ; save the flags (interrupt flag)
        cli                             ; no interrupt between the 3 writes

        mov  al, PIT_MODE_COMMAND
        out  PIT_COMMAND_PORT, al       ; tell the chip what comes next
        mov  ax, [bp+4]                 ; AX = divisor
        out  PIT_CHANNEL0_PORT, al      ; low byte of the divisor
        mov  al, ah
        out  PIT_CHANNEL0_PORT, al      ; high byte of the divisor

        popf                            ; interrupts as they were before
        pop  ax
        pop  bp
        ret  2

; --------------------------------------------------------------------------
; Procedure : TimerHandler   (interrupt routine, runs on every timer tick)
; Purpose   : 1. tick_counter = tick_counter + 1
;             2. only while clock_running = 1: count ticks_this_second; after
;                TICKS_PER_SECOND ticks reset it and subtract 1 from
;                time_left (never below 0)
;             3. continue with the old INT 1Ch routine
; Inputs    : none
; Outputs   : tick_counter, ticks_this_second, time_left updated
; Registers : none changed (no register is used at all)
; Note      : Variables are written with the CS: prefix. In a .COM program
;             CS is our data segment, and DS may point somewhere else when
;             the interrupt arrives, so DS is never touched.
;             No end-of-interrupt is sent: the BIOS INT 08h routine that
;             called us does that.
;             No IRET here: "jmp far" hands over to the old routine with the
;             stack exactly as the interrupt left it, and the old routine's
;             own IRET returns to the BIOS. The flags changed below are
;             restored by that IRET.
; --------------------------------------------------------------------------
TimerHandler:
        inc  word [cs:tick_counter]     ; one more tick

        cmp  byte [cs:clock_running], 0 ; is the game clock running?
        je   .chain                     ; no: the clock stays frozen

        inc  byte [cs:ticks_this_second]
        cmp  byte [cs:ticks_this_second], TICKS_PER_SECOND
        jb   .chain                     ; less than one second so far
        mov  byte [cs:ticks_this_second], 0 ; a full second has passed
        cmp  word [cs:time_left], 0     ; time already at 0?
        je   .chain                     ; yes: do not go below 0
        dec  word [cs:time_left]        ; one second less on the clock

.chain:
        jmp  far [cs:old_timer_offset]  ; go on with the old INT 1Ch routine

; --------------------------------------------------------------------------
; Procedure : WaitForTick
; Purpose   : Wait until the timer has made at least one new tick since the
;             last call. This makes the game loop run once per tick (about
;             30 times a second) on every computer.
; Inputs    : none
; Outputs   : last_tick_seen = the tick_counter value we waited for
; Registers : none changed (AX saved and restored)
; Note      : If the frame took longer than one tick, the procedure returns
;             at once (tick_counter is already different). The game clock is
;             counted by TimerHandler, so it stays correct either way.
; --------------------------------------------------------------------------
WaitForTick:
        push ax
.wait:
        mov  ax, [tick_counter]         ; AX = ticks so far
        cmp  ax, [last_tick_seen]       ; same value as last time?
        je   .wait                      ; yes: no new tick yet, keep waiting
        mov  [last_tick_seen], ax       ; remember it, so this tick counts once
        pop  ax
        ret