; score.asm - owner: Sami Ahsan - stub, filled in later
; ==========================================================================
; FILE    : src/score.asm
; OWNER   : Sami Ahsan (Module 13, first part)
; PURPOSE : The score. It is 32 bits = two 16 bit words (score_lo = low word,
;           score_hi = high word, in data_game.asm) because 999999 does not
;           fit in 16 bits.
;           AddScore is written now because Module 11 (enemies) needs it.
;           The rest of Module 13 (coins, lives, decimal digits) comes later.
; ==========================================================================

; --------------------------------------------------------------------------
; Procedure : AddScore
; Purpose   : Add points to the 32 bit score (PDF 5.4). The score never goes
;             above 999999 (MAX_SCORE): a bigger result is cut to 999999.
; Inputs    : push points (0 to 65535)
;             [bp+4] = points
; Outputs   : score_lo, score_hi updated
; Registers : none changed (AX, BP saved and restored)
; Logic     : ADD adds the low words and may set the carry flag. ADC adds
;             0 to the high word PLUS that carry. So 65530 + 100 correctly
;             becomes 1 in the high word and 94 in the low word.
; Note      : "ret 2" removes the 1 parameter word from the stack.
; --------------------------------------------------------------------------
AddScore:
        push bp
        mov  bp, sp
        push ax

        mov  ax, [bp+4]                 ; AX = points
        add  [score_lo], ax             ; low word + points (may carry)
        adc  word [score_hi], 0         ; high word + carry

        cmp  word [score_hi], MAX_SCORE_HI
        jb   .done                      ; below the limit: fine
        ja   .clamp                     ; above it: cut
        cmp  word [score_lo], MAX_SCORE_LO ; same high word: compare low words
        jbe  .done
.clamp:
        mov  word [score_hi], MAX_SCORE_HI
        mov  word [score_lo], MAX_SCORE_LO
.done:
        pop  ax
        pop  bp
        ret  2