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

; ---- Hero hitbox (Module 10) - calculated by UpdateHeroBox ---------------
; World pixel positions. The hitbox is 12 wide (2 pixels in from each side
; of the 16 pixel sprite) and as tall as the form (16 or 32).
hero_box_left       dw 0                ; 2 bytes, leftmost hitbox column
hero_box_right      dw 0                ; 2 bytes, rightmost hitbox column
hero_box_top        dw 0                ; 2 bytes, top pixel row
hero_box_bottom     dw 0                ; 2 bytes, bottom pixel row (last one)

; ---- Head hit report for Module 12 (set by ResolveHeroY every frame) -----
head_hit            db 0                ; 1 byte, 1 = head hit a solid tile
head_hit_x          dw 0                ; 2 bytes, world x of the head centre
head_hit_y          dw 0                ; 2 bytes, world y, a row inside the tile

; ---- Score, coins, lives (Section 5.4; Module 13) ------------------------
score_lo            dw 0                ; 32-bit score, low word  (first)
score_hi            dw 0                ;               high word (second)
coins               db 0                ; 1 byte, 0 to 99
lives               db START_LIVES      ; 1 byte, 0 to 99

; ---- Enemy table (Section 5.5; Module 11) --------------------------------
; 8 records x 12 bytes = 96 bytes. All zero = every slot empty.
enemy_table         times MAX_ENEMIES*ENEMY_RECORD_SIZE db 0

; ---- Enemy start positions (Section 5.8 "reset to their start positions") -
; One entry = 2 words: type, world x. All stand on the ground (y = ENEMY_START_Y).
; Placed so that every rule can be tested (PDF 5.15): the Goomba at 384 walks
; off the ledge into the pit, the Koopa at 672 turns at the pipe and the pit
; edge, and the Koopa at 752 can kick its shell into the Goomba at 784.
enemy_start_table:
        dw ENEMY_GOOMBA, 160            ; early Goomba, near the start
        dw ENEMY_GOOMBA, 288            ; Goomba before the first pit
        dw ENEMY_GOOMBA, 384            ; Goomba on the ledge after the pit
        dw ENEMY_KOOPA,  672            ; Koopa between the pipe and the pit
        dw ENEMY_KOOPA,  752            ; Koopa before the stairs
        dw ENEMY_GOOMBA, 784            ; Goomba next to that Koopa

; ---- Stomp chain points (Section 5.4), index = stomps since last landing --
; Stomp 11 and more give a 1-UP and no points (checked in StompScore).
stomp_points:
        dw 100, 200, 400, 500, 800, 1000, 2000, 4000, 5000, 8000
; ---- Mushrooms (Module 12) -----------------------------------------------
; Same 12 byte record layout as the enemies (ENEMY_TYPE, ENEMY_X ...).
; 2 records x 12 bytes = 24 bytes. All zero = every slot empty.
mushroom_table      times MAX_MUSHROOMS*ENEMY_RECORD_SIZE db 0

; ---- Coin that jumps out of a "?" block (Module 12) ----------------------
coin_pop_timer      db 0                ; 1 byte, frames left (0 = no coin)
coin_pop_x          dw 0                ; 2 bytes, world x of the block
coin_pop_y          dw 0                ; 2 bytes, world y of the tile above it