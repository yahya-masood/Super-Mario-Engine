; ==========================================================================
; FILE    : src/const_game.asm
; OWNER   : Sami Ahsan (Module 1)
; PURPOSE : Gameplay constants. EQU gives a number a name and uses NO
;           memory. Include this file AFTER const_engine.asm, because it
;           uses TILE_SIZE and GROUND_TOP_Y from that file.
; SOURCE  : PDF Section 5 and Appendix A.4 / A.5, unless marked DESIGN.
; DESIGN  : the PDF does not give this value. It is our own decision and
;           will be listed in the README.
; PENDING : not decided yet, so not defined (see the end of the file).
; ==========================================================================

; ---- Game limits (Appendix A.4) ------------------------------------------
START_LIVES         equ 3               ; lives at a new game
MAX_LIVES           equ 99              ; lives never go above this
HP_SMALL            equ 1               ; health of Small Mario
HP_SUPER            equ 2               ; health of Super Mario (maximum)
GAME_TIME_START     equ 300             ; seconds on the clock each life
COINS_FOR_LIFE      equ 100             ; 100 coins = +1 life, coins -> 0
MAX_ENEMIES         equ 8               ; enemy records active at once
KICK_GRACE_FRAMES   equ 8               ; shell ignores Mario after a kick
                                        ; (PDF: "about 8 frames")

; ---- Maximum score (Appendix A.4) ----------------------------------------
; The score is 32 bits = two 16-bit words. NASM splits 999999 for us:
; "& 0FFFFh" keeps the low 16 bits, ">> 16" keeps the high 16 bits.
MAX_SCORE           equ 999999
MAX_SCORE_LO        equ MAX_SCORE & 0FFFFh      ; = 423Fh
MAX_SCORE_HI        equ MAX_SCORE >> 16         ; = 000Fh

; ---- Hero size and start (Sections 5.1, 5.3, 5.6, 5.8) -------------------
SMALL_HEIGHT        equ TILE_SIZE       ; Small Mario: 16 pixels tall
SUPER_HEIGHT        equ 2*TILE_SIZE     ; Super Mario: 32 pixels tall
HITBOX_WIDTH        equ 12              ; DESIGN: PDF says "about 12"
HITBOX_OFFSET_X     equ (TILE_SIZE-HITBOX_WIDTH)/2  ; DESIGN: centred = 2
HERO_START_X        equ 32              ; world x at level start (5.3)
HERO_START_Y        equ GROUND_TOP_Y-SMALL_HEIGHT   ; DESIGN: 144, derived
                                        ; from "Mario stands on row 9"
PIT_Y               equ 192             ; top of Mario at y >= 192 = pit
DEATH_HOP_PIXELS    equ 48              ; upward hop in the death animation

; ---- Hero form, direction and pose codes ---------------------------------
; DESIGN: the PDF names these but gives no numbers.
FORM_SMALL          equ 0
FORM_SUPER          equ 1
FACING_RIGHT        equ 0
FACING_LEFT         equ 1               ; sprite is mirrored when facing left
POSE_STAND          equ 0
POSE_RUN            equ 1
POSE_JUMP           equ 2

; ---- Physics, 8.8 fixed point (Appendix A.5) -----------------------------
; 8.8 means value * 256: high byte = whole pixels, low byte = 1/256 steps.
; Negative values are two's complement: -5.5 * 256 = -1408 = 0FA80h.
PHYS_WALK_ACCEL     equ 0020h           ;  0.125 px/frame, direction held
PHYS_FRICTION       equ 0010h           ;  0.0625, no direction held
PHYS_MAX_WALK       equ 0180h           ;  1.5
PHYS_MAX_RUN        equ 0280h           ;  2.5 (Left Shift held)
PHYS_GRAVITY        equ 0040h           ;  0.25 added to vy every frame
PHYS_JUMP_START     equ 0FA80h          ; -5.5 (about 3.8 tiles high)
PHYS_JUMP_CUTOFF    equ 0FE00h          ; -2.0 (Space released while rising)
PHYS_MAX_FALL       equ 0400h           ;  4.0
PHYS_STOMP_BOUNCE   equ 0FD00h          ; -3.0

; ---- Speeds of other objects (Appendix A.5), magnitudes, 8.8 -------------
SPEED_GOOMBA        equ 0080h           ; 0.5  (whole 0, fraction 80h)
SPEED_KOOPA         equ 00C0h           ; 0.75 (whole 0, fraction C0h)
SPEED_SHELL         equ 0300h           ; 3.0  (whole 3, fraction 00h)
SPEED_MUSHROOM      equ 0100h           ; 1.0  (whole 1, fraction 00h)

; ---- DrawSprite flags (Module 4). DESIGN: the PDF gives no flag values ---
; The 4th parameter of DrawSprite is a word. Each flag is one bit; add the
; flags you want together (example: SPRITE_MIRROR + SPRITE_TALL).
SPRITE_MIRROR       equ 1               ; bit 0: draw flipped left-right
SPRITE_HALF         equ 2               ; bit 1: half-transparent (every
                                        ;        second pixel, used to blink)
SPRITE_TALL         equ 4               ; bit 2: sprite has 32 rows (Super
                                        ;        Mario) instead of 16

; ---- Enemy record layout (Section 5.5). DESIGN, PROVISIONAL --------------
; Each constant is the OFFSET of a field from the start of one record.
ENEMY_TYPE          equ 0               ; db  ENEMY_xxx below, 0 = empty slot
ENEMY_STATE         equ 1               ; db  state (values PENDING)
ENEMY_X             equ 2               ; dw  world x, whole pixels
ENEMY_XFRAC         equ 4               ; db  world x, fraction (1/256)
ENEMY_DIR           equ 5               ; db  FACING_RIGHT or FACING_LEFT
ENEMY_Y             equ 6               ; dw  y of top, 8.8 fixed point
ENEMY_SPEED         equ 8               ; dw  speed magnitude, 8.8
ENEMY_TIMER         equ 10              ; dw  flat timer / kick grace
ENEMY_RECORD_SIZE   equ 12              ; total bytes per record

ENEMY_NONE          equ 0               ; type: empty record
ENEMY_GOOMBA        equ 1               ; type: Goomba
ENEMY_KOOPA         equ 2               ; type: Koopa (a shell is a STATE
                                        ; of a Koopa, not a separate type)

; ---- PENDING (intentionally NOT defined yet) -----------------------------
; PHYS_BRAKE          : PDF 5.2 says braking is faster than friction, but
;                       Appendix A.5 gives no value.
; TICKS_PER_SECOND    : and every constant built from it (invulnerability
;                       2 s, flat Goomba 1 s, death animation 1.5 s, Life-lost
;                       screen 2 s, win slide 1 s, win walk 1 s).
; ENEMY state values  : waiting, walking, flat, shell still, shell sliding.
; Units of invuln_timer and ENEMY_TIMER.