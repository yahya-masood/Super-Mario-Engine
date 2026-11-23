
; ==========================================================================
; FILE    : src/data_engine.asm
; OWNER   : Yahya Masood (Module 1)
; PURPOSE : Engine variables grouped by purpose.
; ==========================================================================

; ---- Game state ----------------------------------------------------------
game_state          db STATE_TITLE
exit_requested      db 0

; ---- Camera --------------------------------------------------------------
camera_x            dw 0
; ---- Frame buffer (Module 5) ---------------------------------------------
framebuffer_segment dw 0                ; segment of the off-screen buffer,
                                        ; set by InitFrameBuffer

; ---- Message printed if the buffer cannot be allocated -------------------
msg_no_memory       db 'Not enough memory for the frame buffer.', 13, 10, '$'
; ---- Clock ---------------------------------------------------------------
tick_counter        dw 0
time_left           dw 300
ticks_this_second   db 0

; ---- Keyboard ------------------------------------------------------------
key_table           times 128 db 0

; ---- Saved interrupt vectors ---------------------------------------------
old_kbd_offset      dw 0
old_kbd_segment     dw 0
old_timer_offset    dw 0
old_timer_segment   dw 0

; ---- Messages ------------------------------------------------------------
msg_module1_ok      db 'Super Mario Engine - Module 1 OK. Returning to DOS.', 13, 10, '$'
