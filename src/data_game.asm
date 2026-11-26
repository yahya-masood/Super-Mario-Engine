; data_game.asm - owner: Sami Ahsan - stub, filled in later
; ==========================================================================
; FILE    : src/data_game.asm
; OWNER   : Sami Ahsan (Module 1)
; PURPOSE : Hero, score, coins, lives and enemy variables, grouped by
;           purpose. db = 1 byte, dw = 2 bytes (low byte stored first).
;           The starting values apply only when the program loads;
;           ResetLevel and NewGame (Module 15) must set them again.
; ==========================================================================

; ---- Hero position (Module 9) --------------------------------------------
; Horizontal: whole pixels (dw) + separate fraction (db). The world is 960
; pixels wide, and an 8.8 word cannot hold a whole part above 255.
; Read together as one number:  hero_x . hero_x_frac
hero_x              dw HERO_START_X     ; 2 bytes, world x, whole pixels
hero_x_frac         db 0                ; 1 byte,  fraction in 1/256 pixel
; Vertical: ordinary 8.8 word (high byte = whole pixels).
hero_y              dw HERO_START_Y*256 ; 2 bytes, top of sprite, 8.8
hero_prev_feet_y    dw (HERO_START_Y+SMALL_HEIGHT)*256
                                        ; 2 bytes, 8.8, y of the FEET in the
                                        ; previous frame (stomp test, 5.6)

; ---- Hero speed, signed 8.8 (two's complement) ---------------------------
hero_vx             dw 0                ; 2 bytes, horizontal speed
hero_vy             dw 0                ; 2 bytes, vertical speed, up = negative

; ---- Hero state (Sections 5.1, 5.2; Module 9) ----------------------------
hero_facing         db FACING_RIGHT     ; 1 byte, which way he looks
hero_pose           db POSE_STAND       ; 1 byte, which sprite to draw
on_ground           db 1                ; 1 byte, 1 = standing on solid ground
form                db FORM_SMALL       ; 1 byte, FORM_SMALL or FORM_SUPER
hp                  db HP_SMALL         ; 1 byte, 1 or 2
                                        ; PENDING: exact roles of form and hp.
                                        ; Until decided, they must never
                                        ; disagree (Small = hp 1, Super = 2).
invuln_timer        dw 0                ; 2 bytes, blink time left
                                        ; (unit PENDING until timer design)
stomp_chain         db 0                ; 1 byte, stomps since last landing
; ---- Hero collision data (Module 10) -------------------------------------
hero_box_left       dw 0                ; left edge of hero hitbox
hero_box_right      dw 0                ; right edge of hero hitbox
hero_box_top        dw 0                ; top edge of hero hitbox
hero_box_bottom     dw 0                ; bottom edge of hero hitbox

head_hit            db 0                ; 1 = hero hit a tile from below
head_hit_x          dw 0                ; world x of the head collision
head_hit_y          dw 0                ; world y of the head collision

; ---- Score, coins, lives (Section 5.4; Module 13) ------------------------
score_lo            dw 0                ; 32-bit score, low word  (first)
score_hi            dw 0                ;               high word (second)
coins               db 0                ; 1 byte, 0 to 99
lives               db START_LIVES      ; 1 byte, 0 to 99

; ---- Enemy table (Section 5.5; Module 11) --------------------------------
; 8 records x 12 bytes = 96 bytes. All zero = every slot empty.
enemy_table         times MAX_ENEMIES*ENEMY_RECORD_SIZE db 0