
; ==========================================================================
; FILE    : src/keyboard.asm
; OWNER   : Yahya Masood (Module 7)
; PURPOSE : Install, remove and handle our keyboard INT 09h handler.
;           key_table contains 128 entries:
;           1 = key pressed/held, 0 = key released.
; ==========================================================================

DOS_GET_VECTOR      equ 35h
DOS_SET_VECTOR      equ 25h
KEYBOARD_INT        equ 09h
KEYBOARD_PORT       equ 60h
PIC_PORT            equ 20h
PIC_EOI             equ 20h

; ==========================================================================
; InstallKeyboardHandler
; Save old INT 09h vector and install our handler.
; ==========================================================================

InstallKeyboardHandler:
        push ax
        push bx
        push dx
        push ds
        push es

        ; Ensure our data segment is being used.
        push cs
        pop  ds

        cmp  word [old_kbd_segment], 0
        jne  .done

        ; Get the current INT 09h vector.
        mov  ah, DOS_GET_VECTOR
        mov  al, KEYBOARD_INT
        int  21h

        ; DOS returns old vector in ES:BX.
        push cs
        pop  ds

        mov  [old_kbd_offset], bx
        mov  [old_kbd_segment], es

        ; Install KeyboardHandler using DS:DX.
        mov  dx, KeyboardHandler
        mov  ah, DOS_SET_VECTOR
        mov  al, KEYBOARD_INT
        int  21h

.done:
        pop  es
        pop  ds
        pop  dx
        pop  bx
        pop  ax
        ret

; ==========================================================================
; RemoveKeyboardHandler
; Restore original INT 09h vector.
; ==========================================================================

RemoveKeyboardHandler:
        push ax
        push dx
        push ds

        ; Ensure our variables are accessed through our own DS.
        push cs
        pop  ds

        mov  ax, [old_kbd_segment]
        cmp  ax, 0
        je   .done

        mov  dx, [old_kbd_offset]

        ; DS:DX = original interrupt handler address.
        mov  ds, ax
        mov  ah, DOS_SET_VECTOR
        mov  al, KEYBOARD_INT
        int  21h

        ; Return to our own data segment.
        push cs
        pop  ds

        mov  word [old_kbd_segment], 0

.done:
        pop  ds
        pop  dx
        pop  ax
        ret

; ==========================================================================
; KeyboardHandler - INT 09h
; Read scan code and update key_table.
; ==========================================================================

KeyboardHandler:
        push ax
        push bx
        push ds

        ; DS = our program's segment.
        push cs
        pop  ds

        ; Read keyboard scan code.
        in   al, KEYBOARD_PORT

        ; Ignore E0h extended-key prefix.
        cmp  al, KEY_EXTENDED_PREFIX
        je   .finish

        ; Scan code index = lower 7 bits (0..127).
        mov  bl, al
        and  bl, 7Fh
        mov  bh, 0

        ; Bit 7 identifies a key release.
        test al, KEY_RELEASE_BIT
        jnz  .released

        ; Key pressed.
        mov  byte [key_table+bx], 1
        jmp  .finish

.released:
        ; Key released.
        mov  byte [key_table+bx], 0

.finish:
        ; PIC End Of Interrupt.
        mov  al, PIC_EOI
        out  PIC_PORT, al

        pop  ds
        pop  bx
        pop  ax
        iret
