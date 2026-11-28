; enemies.asm - owner: Sami Ahsan - stub, filled in later
; ==========================================================================
; FILE    : src/enemies.asm
; OWNER   : Sami Ahsan (Module 11)
; PURPOSE : Goomba, Koopa Troopa and Koopa shell (PDF Sections 5.4 - 5.7).
;           The enemies are fixed size records in enemy_table (data_game.asm),
;           ENEMY_RECORD_SIZE = 12 bytes each. A field is reached with based
;           addressing: SI or BX holds the start of one record and the field
;           offset is added, for example  [si+ENEMY_X].
;             ENEMY_TYPE   db   0 = empty slot, GOOMBA, KOOPA
;             ENEMY_STATE  db   WAITING, WALKING, FLAT, SHELL_STILL, SHELL_SLIDE
;             ENEMY_X      dw   world x, whole pixels
;             ENEMY_XFRAC  db   fraction of x (1/256 pixel)
;             ENEMY_DIR    db   FACING_RIGHT or FACING_LEFT
;             ENEMY_Y      dw   top y, 8.8 (always a whole number of pixels)
;             ENEMY_SPEED  dw   speed (size only), 8.8
;             ENEMY_TIMER  dw   flat time, or the 8 frame grace time of a shell
;           A procedure that works on one record gets its ADDRESS (start of
;           the record) on the stack.
;           Per frame the game loop calls (PDF 5.13):
;             UpdateEnemies          step 4   move the enemies
;             ResolveHeroEnemies     step 5   Mario against the enemies
;             UpdateInvulnerability  step 6   blink time of Mario
;             DrawEnemies            step 9   draw them
;           Hurting Mario: hp = 0 means Mario is dead; the game loop (death
;           check, step 7) reacts to it.
; ==========================================================================

; --------------------------------------------------------------------------
; Procedure : ResetEnemies
; Purpose   : Put all enemies back to their start positions (new life, new
;             game, PDF 5.8): clear the table, then copy the entries of
;             enemy_start_table into the first records. Every enemy starts
;             WAITING, facing left, on the ground.
; Inputs    : none
; Outputs   : enemy_table
; Registers : none changed (AX, CX, SI, DI saved and restored)
; --------------------------------------------------------------------------
ResetEnemies:
        push ax
        push cx
        push si
        push di

        mov  si, enemy_table            ; SI = first record
        mov  cx, MAX_ENEMIES
.clear:
        mov  byte [si+ENEMY_TYPE], ENEMY_NONE   ; empty slot
        add  si, ENEMY_RECORD_SIZE      ; next record
        dec  cx
        jnz  .clear

        mov  si, enemy_table            ; SI = record to fill
        mov  di, enemy_start_table      ; DI = entry (type word, x word)
        mov  cx, ENEMY_START_COUNT
.fill:
        mov  ax, [di]                   ; type
        mov  [si+ENEMY_TYPE], al
        mov  byte [si+ENEMY_STATE], ENEMY_STATE_WAITING
        mov  ax, [di+2]                 ; world x
        mov  [si+ENEMY_X], ax
        mov  byte [si+ENEMY_XFRAC], 0
        mov  byte [si+ENEMY_DIR], FACING_LEFT
        mov  word [si+ENEMY_Y], ENEMY_START_Y*256
        mov  word [si+ENEMY_TIMER], 0
        mov  word [si+ENEMY_SPEED], SPEED_GOOMBA
        cmp  byte [si+ENEMY_TYPE], ENEMY_GOOMBA
        je   .speed_done
        mov  word [si+ENEMY_SPEED], SPEED_KOOPA ; a Koopa is faster
.speed_done:
        add  si, ENEMY_RECORD_SIZE
        add  di, 4                      ; next start entry (2 words)
        dec  cx
        jnz  .fill

        pop  di
        pop  si
        pop  cx
        pop  ax
        ret

; --------------------------------------------------------------------------
; Procedure : IsSolidPoint
; Purpose   : Is the tile at the world pixel (px, py) solid (code 1 to 10)?
; Inputs    : push px, push py
;             [bp+6] = px   [bp+4] = py
; Outputs   : AX = 1 if solid, otherwise 0
; Registers : only AX changed (BP saved and restored)
; Note      : uses TileInRange (collision.asm). "ret 4" removes 2 words.
; --------------------------------------------------------------------------
IsSolidPoint:
        push bp
        mov  bp, sp

        mov  ax, [bp+6]
        push ax                         ; px
        mov  ax, [bp+4]
        push ax                         ; py
        mov  ax, TILE_GROUND
        push ax                         ; low
        mov  ax, TILE_STAIR
        push ax                         ; high
        call TileInRange

        pop  bp
        ret  4

; --------------------------------------------------------------------------
; Procedure : EnemyLeadingX
; Purpose   : The x of the front pixel of an enemy: its right edge (x + 15)
;             when it looks right, its left edge (x) when it looks left.
; Inputs    : push record address
;             [bp+4] = record
; Outputs   : AX = world x of the front pixel
; Registers : only AX changed (BX, BP saved and restored)
; --------------------------------------------------------------------------
EnemyLeadingX:
        push bp
        mov  bp, sp
        push bx

        mov  bx, [bp+4]
        mov  ax, [bx+ENEMY_X]
        cmp  byte [bx+ENEMY_DIR], FACING_RIGHT
        jne  .done                      ; looking left: the front is x
        add  ax, TILE_SIZE-1            ; looking right: x + 15
.done:
        pop  bx
        pop  bp
        ret  2

; --------------------------------------------------------------------------
; Procedure : EnemyGroundAtX
; Purpose   : Is there solid ground just below the enemy's feet at world x px?
;             (the tile in the pixel row y + 16)
; Inputs    : push record address, push px
;             [bp+6] = record   [bp+4] = px
; Outputs   : AX = 1 if there is ground, otherwise 0
; Registers : only AX changed (BX, BP saved and restored)
; Note      : "ret 4" removes 2 words.
; --------------------------------------------------------------------------
EnemyGroundAtX:
        push bp
        mov  bp, sp
        push bx

        mov  bx, [bp+6]
        mov  ax, [bp+4]
        push ax                         ; px
        mov  ax, [bx+ENEMY_Y]           ; 8.8: whole pixels are in AH
        mov  al, ah
        mov  ah, 0                      ; AX = whole y
        add  ax, TILE_SIZE              ; first pixel row below the feet
        push ax                         ; py
        call IsSolidPoint

        pop  bx
        pop  bp
        ret  4

; --------------------------------------------------------------------------
; Procedure : EnemyWallAhead
; Purpose   : Is there a solid tile in front of the enemy (front pixel,
;             half way up its body)?
; Inputs    : push record address
;             [bp+4] = record
; Outputs   : AX = 1 if a wall is in front, otherwise 0
; Registers : only AX changed (BX, BP saved and restored)
; --------------------------------------------------------------------------
EnemyWallAhead:
        push bp
        mov  bp, sp
        push bx

        mov  bx, [bp+4]
        push bx
        call EnemyLeadingX              ; AX = x of the front pixel
        push ax                         ; px
        mov  ax, [bx+ENEMY_Y]
        mov  al, ah
        mov  ah, 0                      ; AX = whole y
        add  ax, TILE_SIZE/2            ; half way up the body
        push ax                         ; py
        call IsSolidPoint

        pop  bx
        pop  bp
        ret  2

; --------------------------------------------------------------------------
; Procedure : EnemyGroundAhead
; Purpose   : Is there ground below the front edge of the enemy? (A Koopa
;             turns round when there is none: platform edge.)
; Inputs    : push record address
;             [bp+4] = record
; Outputs   : AX = 1 if there is ground ahead, otherwise 0
; Registers : only AX changed (BX, BP saved and restored)
; --------------------------------------------------------------------------
EnemyGroundAhead:
        push bp
        mov  bp, sp
        push bx

        mov  bx, [bp+4]
        push bx
        call EnemyLeadingX              ; AX = x of the front pixel
        push bx                         ; record
        push ax                         ; px
        call EnemyGroundAtX

        pop  bx
        pop  bp
        ret  2

; --------------------------------------------------------------------------
; Procedure : MoveEnemyX
; Purpose   : Move an enemy sideways by its speed, in the direction it looks
;             (back = 0) or the opposite way (back = 1, to undo a step).
;             Like Mario, x is a whole word plus a fraction byte:
;             right: ADD the fraction bytes, ADC the whole part
;             left : SUB the fraction bytes, SBB the whole part
; Inputs    : push record address, push back (0 or 1)
;             [bp+6] = record   [bp+4] = back
; Outputs   : ENEMY_X, ENEMY_XFRAC of the record
; Registers : none changed (AX, BX, DX, BP saved and restored)
; Note      : speed 0300h (shell) has the whole part 3, so the whole part
;             of the speed is always added; "mov dh, 0" keeps the carry flag.
;             "ret 4" removes 2 words.
; --------------------------------------------------------------------------
MoveEnemyX:
        push bp
        mov  bp, sp
        push ax
        push bx
        push dx

        mov  bx, [bp+6]                 ; BX = record
        mov  al, [bx+ENEMY_DIR]
        xor  al, [bp+4]                 ; back = 1 turns the direction round
        mov  dx, [bx+ENEMY_SPEED]       ; DL = fraction, DH = whole part
        cmp  al, FACING_RIGHT
        jne  .left
        add  [bx+ENEMY_XFRAC], dl       ; fraction + fraction (may carry)
        mov  dl, dh
        mov  dh, 0                      ; DX = whole part of the speed
        adc  [bx+ENEMY_X], dx           ; x + whole part + carry
        jmp  .done
.left:
        sub  [bx+ENEMY_XFRAC], dl       ; fraction - fraction (may borrow)
        mov  dl, dh
        mov  dh, 0
        sbb  [bx+ENEMY_X], dx           ; x - whole part - borrow
.done:
        pop  dx
        pop  bx
        pop  ax
        pop  bp
        ret  4

; --------------------------------------------------------------------------
; Procedure : EnemyFalls
; Purpose   : Gravity for an enemy. If there is solid ground below the middle
;             of its feet it stands (and is put exactly on top of the tile).
;             Otherwise it falls ENEMY_FALL_SPEED pixels this frame (and is
;             put on the tile if it lands).
; Inputs    : push record address
;             [bp+4] = record
; Outputs   : AX = 1 if the enemy stands on the ground now, 0 if it is in
;             the air; ENEMY_Y of the record
; Registers : only AX changed (BX, CX, BP saved and restored)
; --------------------------------------------------------------------------
EnemyFalls:
        push bp
        mov  bp, sp
        push bx
        push cx

        mov  bx, [bp+4]
        mov  cx, [bx+ENEMY_X]
        add  cx, TILE_SIZE/2            ; CX = x of the middle of the enemy
        push bx
        push cx
        call EnemyGroundAtX             ; ground below?
        cmp  ax, 0
        jne  .land                      ; yes: stand
        add  word [bx+ENEMY_Y], ENEMY_FALL_SPEED*256 ; no: fall
        push bx
        push cx
        call EnemyGroundAtX             ; ground below after the fall?
        cmp  ax, 0
        je   .air                       ; still nothing: in the air
.land:
        mov  ax, [bx+ENEMY_Y]
        mov  al, ah
        mov  ah, 0                      ; AX = whole y
        add  ax, TILE_SIZE              ; the pixel row below the feet
        and  ax, 0FFF0h                 ; top edge of that tile
        sub  ax, TILE_SIZE              ; enemy top = tile top - 16
        mov  ah, al                     ; y = whole pixels in the high byte
        mov  al, 0
        mov  [bx+ENEMY_Y], ax
        mov  ax, 1
        jmp  .done
.air:
        mov  ax, 0
.done:
        pop  cx
        pop  bx
        pop  bp
        ret  2

; --------------------------------------------------------------------------
; Procedure : EnemyHitsEnemy
; Purpose   : Does this enemy overlap another enemy that is WALKING or a
;             stationary shell? (Walkers turn round at other enemies.)
; Inputs    : push record address
;             [bp+4] = record
; Outputs   : AX = 1 if it overlaps such an enemy, otherwise 0
; Registers : only AX changed (BX, CX, SI, DI, BP saved and restored)
; --------------------------------------------------------------------------
EnemyHitsEnemy:
        push bp
        mov  bp, sp
        push bx
        push cx
        push si
        push di

        mov  si, [bp+4]                 ; SI = this enemy
        mov  di, enemy_table            ; DI = the other enemy
        mov  cx, MAX_ENEMIES
.next:
        cmp  di, si
        je   .skip                      ; not itself
        cmp  byte [di+ENEMY_TYPE], ENEMY_NONE
        je   .skip
        cmp  byte [di+ENEMY_STATE], ENEMY_STATE_WALKING
        je   .check
        cmp  byte [di+ENEMY_STATE], ENEMY_STATE_SHELL_STILL
        jne  .skip
.check:
        mov  ax, [si+ENEMY_X]           ; rectangle 1: this enemy
        push ax
        mov  bx, [si+ENEMY_Y]
        mov  bl, bh
        mov  bh, 0                      ; whole y
        push bx
        mov  ax, TILE_SIZE
        push ax                         ; width
        push ax                         ; height
        mov  ax, [di+ENEMY_X]           ; rectangle 2: the other enemy
        push ax
        mov  bx, [di+ENEMY_Y]
        mov  bl, bh
        mov  bh, 0
        push bx
        mov  ax, TILE_SIZE
        push ax
        push ax
        call RectOverlap
        cmp  ax, 0
        jne  .done                      ; AX = 1: overlap
.skip:
        add  di, ENEMY_RECORD_SIZE
        dec  cx
        jnz  .next
        mov  ax, 0                      ; no overlap with any
.done:
        pop  di
        pop  si
        pop  cx
        pop  bx
        pop  bp
        ret  2

; --------------------------------------------------------------------------
; Procedure : StepEnemy
; Purpose   : One step of a walking enemy or sliding shell: move forward,
;             then look whether it must turn round. If it must, the step is
;             taken back and the direction is flipped.
;             It turns round when
;               - there is a wall in front, or
;               - edge_check = 1 and there is no ground ahead (Koopa), or
;               - others_check = 1 and it overlaps another enemy.
; Inputs    : push record address, push edge_check, push others_check
;             [bp+8] = record   [bp+6] = edge_check   [bp+4] = others_check
; Outputs   : ENEMY_X, ENEMY_XFRAC, ENEMY_DIR of the record
; Registers : none changed (AX, BX, BP saved and restored)
; Note      : "ret 6" removes 3 words.
; --------------------------------------------------------------------------
StepEnemy:
        push bp
        mov  bp, sp
        push ax
        push bx

        mov  bx, [bp+8]                 ; BX = record
        push bx
        mov  ax, 0
        push ax                         ; back = 0: forward
        call MoveEnemyX

        push bx
        call EnemyWallAhead
        cmp  ax, 0
        jne  .turn                      ; wall in front

        cmp  word [bp+6], 0
        je   .no_edge_check
        push bx
        call EnemyGroundAhead
        cmp  ax, 0
        je   .turn                      ; no ground ahead: platform edge
.no_edge_check:

        cmp  word [bp+4], 0
        je   .done
        push bx
        call EnemyHitsEnemy
        cmp  ax, 0
        je   .done                      ; free way: keep the step
.turn:
        push bx
        mov  ax, 1
        push ax                         ; back = 1: undo the step
        call MoveEnemyX
        xor  byte [bx+ENEMY_DIR], 1     ; turn round (0 <-> 1)
.done:
        pop  bx
        pop  ax
        pop  bp
        ret  6

; --------------------------------------------------------------------------
; Procedure : ShellKills
; Purpose   : A sliding shell removes every WALKING Goomba or Koopa that it
;             overlaps and adds 500 points for each (PDF 5.4, 5.6).
;             (Stationary shells, flat Goombas and waiting enemies are not
;             hit.)
; Inputs    : push record address of the shell
;             [bp+4] = record
; Outputs   : killed enemies removed (type = 0), score
; Registers : none changed (AX, BX, CX, SI, DI, BP saved and restored)
; --------------------------------------------------------------------------
ShellKills:
        push bp
        mov  bp, sp
        push ax
        push bx
        push cx
        push si
        push di

        mov  si, [bp+4]                 ; SI = the shell
        mov  di, enemy_table            ; DI = the possible victim
        mov  cx, MAX_ENEMIES
.next:
        cmp  di, si
        je   .skip
        cmp  byte [di+ENEMY_TYPE], ENEMY_NONE
        je   .skip
        cmp  byte [di+ENEMY_STATE], ENEMY_STATE_WALKING
        jne  .skip
        mov  ax, [si+ENEMY_X]           ; rectangle 1: the shell
        push ax
        mov  bx, [si+ENEMY_Y]
        mov  bl, bh
        mov  bh, 0
        push bx
        mov  ax, TILE_SIZE
        push ax
        push ax
        mov  ax, [di+ENEMY_X]           ; rectangle 2: the victim
        push ax
        mov  bx, [di+ENEMY_Y]
        mov  bl, bh
        mov  bh, 0
        push bx
        mov  ax, TILE_SIZE
        push ax
        push ax
        call RectOverlap
        cmp  ax, 0
        je   .skip
        mov  byte [di+ENEMY_TYPE], ENEMY_NONE   ; the victim is gone
        mov  ax, 500
        push ax
        call AddScore                   ; +500 for every enemy
.skip:
        add  di, ENEMY_RECORD_SIZE
        dec  cx
        jnz  .next

        pop  di
        pop  si
        pop  cx
        pop  bx
        pop  ax
        pop  bp
        ret  2

; --------------------------------------------------------------------------
; Procedure : UpdateOneEnemy
; Purpose   : One frame of one enemy (PDF 5.5):
;             - removed when more than 32 pixels left of the screen or when
;               it has fallen below the map
;             - WAITING : starts walking when it is within one tile of the
;               visible screen (screen x < 320 + 16)
;             - WALKING : gravity, then a step (turns at walls and at other
;               enemies; a Koopa also at platform edges); a Goomba walks off
;               ledges and falls
;             - FLAT    : the flat Goomba time counts down, then it is removed
;             - SHELL_STILL : gravity; the grace timer counts down
;             - SHELL_SLIDE : grace timer, gravity, a step (bounces off
;               walls) and it kills the enemies it touches
; Inputs    : push record address
;             [bp+4] = record
; Outputs   : the record (and removed victims)
; Registers : none changed (AX, BX, DX, BP saved and restored)
; --------------------------------------------------------------------------
UpdateOneEnemy:
        push bp
        mov  bp, sp
        push ax
        push bx
        push dx

        mov  bx, [bp+4]                 ; BX = record
        mov  ax, [bx+ENEMY_X]
        push ax
        call WorldToScreenX             ; AX = screen x (Module 6)
        cmp  ax, -2*TILE_SIZE           ; more than 32 pixels left of screen?
        jl   .remove
        cmp  byte [bx+ENEMY_Y+1], VISIBLE_HEIGHT ; fallen below the map?
        jae  .remove

        mov  dl, [bx+ENEMY_STATE]
        cmp  dl, ENEMY_STATE_WAITING
        jne  .not_waiting
        cmp  ax, SCREEN_WIDTH+TILE_SIZE ; still far to the right?
        jge  .done                      ; yes: keep waiting
        mov  byte [bx+ENEMY_STATE], ENEMY_STATE_WALKING
        jmp  .done

.not_waiting:
        cmp  dl, ENEMY_STATE_WALKING
        je   .walking
        cmp  dl, ENEMY_STATE_FLAT
        je   .flat
        cmp  dl, ENEMY_STATE_SHELL_STILL
        je   .shell_still

; ---- sliding shell -------------------------------------------------------
        cmp  word [bx+ENEMY_TIMER], 0
        je   .slide_move
        dec  word [bx+ENEMY_TIMER]      ; grace time counts down
.slide_move:
        push bx
        call EnemyFalls
        cmp  ax, 0
        je   .slide_kill                ; in the air: no sideways move
        push bx                         ; step: record,
        mov  ax, 0
        push ax                         ;       edge_check = 0,
        push ax                         ;       others_check = 0
        call StepEnemy                  ; (a wall makes it bounce)
.slide_kill:
        push bx
        call ShellKills
        jmp  .done

; ---- walking Goomba or Koopa --------------------------------------------
.walking:
        push bx
        call EnemyFalls
        cmp  ax, 0
        je   .done                      ; in the air: it falls, no walking
        mov  ax, 0                      ; edge_check: 0 for a Goomba
        cmp  byte [bx+ENEMY_TYPE], ENEMY_KOOPA
        jne  .goomba_step
        mov  ax, 1                      ; a Koopa checks for the platform edge
.goomba_step:
        push bx
        push ax                         ; edge_check
        mov  ax, 1
        push ax                         ; others_check = 1
        call StepEnemy
        jmp  .done

; ---- flat Goomba ---------------------------------------------------------
.flat:
        dec  word [bx+ENEMY_TIMER]
        jnz  .done                      ; time is not over
        jmp  .remove

; ---- stationary shell ----------------------------------------------------
.shell_still:
        push bx
        call EnemyFalls
        cmp  word [bx+ENEMY_TIMER], 0
        je   .done
        dec  word [bx+ENEMY_TIMER]      ; grace time counts down
        jmp  .done

.remove:
        mov  byte [bx+ENEMY_TYPE], ENEMY_NONE
.done:
        pop  dx
        pop  bx
        pop  ax
        pop  bp
        ret  2

; --------------------------------------------------------------------------
; Procedure : UpdateEnemies
; Purpose   : Frame step 4: update every enemy record (loop over the table
;             with indexed addressing, skipping empty slots).
; Inputs    : none
; Outputs   : enemy_table
; Registers : none changed (CX, SI saved and restored)
; --------------------------------------------------------------------------
UpdateEnemies:
        push cx
        push si

        mov  si, enemy_table
        mov  cx, MAX_ENEMIES
.next:
        cmp  byte [si+ENEMY_TYPE], ENEMY_NONE
        je   .skip
        push si
        call UpdateOneEnemy
.skip:
        add  si, ENEMY_RECORD_SIZE
        dec  cx
        jnz  .next

        pop  si
        pop  cx
        ret

; --------------------------------------------------------------------------
; Procedure : StompScore
; Purpose   : Points for a stomp (PDF 5.4): the table stomp_points, indexed
;             by stomp_chain (stomps since the last landing). From the 11th
;             stomp on the reward is one extra life (not above MAX_LIVES) and
;             no points. Then stomp_chain is increased (not above 10).
; Inputs    : none (reads stomp_chain)
; Outputs   : score, lives, stomp_chain
; Registers : none changed (AX, BX saved and restored)
; --------------------------------------------------------------------------
StompScore:
        push ax
        push bx

        mov  bl, [stomp_chain]
        mov  bh, 0                      ; BX = number of the stomp (0 = first)
        cmp  bx, STOMP_CHAIN_MAX
        jae  .extra_life
        shl  bx, 1                      ; word table: index * 2
        mov  ax, [stomp_points+bx]
        push ax
        call AddScore
        jmp  .count
.extra_life:
        cmp  byte [lives], MAX_LIVES
        jae  .count
        inc  byte [lives]               ; 1-UP
.count:
        cmp  byte [stomp_chain], STOMP_CHAIN_MAX
        jae  .done
        inc  byte [stomp_chain]
.done:
        pop  bx
        pop  ax
        ret

; --------------------------------------------------------------------------
; Procedure : BounceHero
; Purpose   : Mario bounces up after a stomp: PHYS_STOMP_BOUNCE, or the
;             higher PHYS_STOMP_BOUNCE_HELD while Space is held (PDF 5.6).
; Inputs    : none
; Outputs   : hero_vy, on_ground
; Registers : none changed
; --------------------------------------------------------------------------
BounceHero:
        mov  word [hero_vy], PHYS_STOMP_BOUNCE
        cmp  byte [key_table+KEY_SPACE], 0
        je   .done
        mov  word [hero_vy], PHYS_STOMP_BOUNCE_HELD
.done:
        mov  byte [on_ground], 0
        ret

; --------------------------------------------------------------------------
; Procedure : HurtHero
; Purpose   : Mario is touched by an enemy (PDF 5.7):
;             - invulnerable: nothing happens
;             - Super (hp 2): becomes Small (hp 1), invulnerable for
;               INVULN_TICKS, and his FEET STAY WHERE THEY ARE, so his top
;               moves down by 16 pixels (y_top = y_feet - height)
;             - Small (hp 1): hp = 0, which means "Mario is dead"
; Inputs    : none
; Outputs   : hp, form, hero_y, invuln_timer
; Registers : none changed
; --------------------------------------------------------------------------
HurtHero:
        cmp  word [invuln_timer], 0
        jne  .done                      ; invulnerable: no effect
        cmp  byte [hp], HP_SUPER
        jne  .dies
        mov  byte [form], FORM_SMALL    ; becomes Small
        mov  byte [hp], HP_SMALL
        add  word [hero_y], (SUPER_HEIGHT-SMALL_HEIGHT)*256 ; feet stay fixed
        mov  word [invuln_timer], INVULN_TICKS
        jmp  .done
.dies:
        mov  byte [hp], 0               ; dead
.done:
        ret

; --------------------------------------------------------------------------
; Procedure : HeroTouchesEnemy
; Purpose   : Mario overlaps an enemy: decide what happens (PDF 5.5, 5.6):
;             - stationary shell: KICK, +400, it slides away from Mario at
;               SPEED_SHELL, with KICK_GRACE_FRAMES frames of grace; Mario is
;               not hurt
;             - otherwise StompOrHurt: on a STOMP a Goomba becomes flat, a
;               Koopa becomes a stationary shell (with grace time), a sliding
;               shell stops; stomp chain points, Mario bounces
;             - otherwise Mario is hurt (HurtHero)
; Inputs    : push record address
;             [bp+4] = record
; Outputs   : the record, score, Mario's variables
; Registers : none changed (AX, BX, DX, BP saved and restored)
; --------------------------------------------------------------------------
HeroTouchesEnemy:
        push bp
        mov  bp, sp
        push ax
        push bx
        push dx

        mov  bx, [bp+4]                 ; BX = record
        cmp  byte [bx+ENEMY_STATE], ENEMY_STATE_SHELL_STILL
        jne  .not_still

        mov  ax, 400                    ; ---- kick a stationary shell
        push ax
        call AddScore
        mov  ax, [hero_box_left]
        add  ax, [hero_box_right]
        shr  ax, 1                      ; AX = middle of Mario
        mov  dx, [bx+ENEMY_X]
        add  dx, TILE_SIZE/2            ; DX = middle of the shell
        mov  byte [bx+ENEMY_DIR], FACING_RIGHT  ; Mario left of it: go right
        cmp  ax, dx
        jb   .kick_dir_done
        mov  byte [bx+ENEMY_DIR], FACING_LEFT   ; Mario right of it: go left
.kick_dir_done:
        mov  byte [bx+ENEMY_STATE], ENEMY_STATE_SHELL_SLIDE
        mov  word [bx+ENEMY_SPEED], SPEED_SHELL
        mov  word [bx+ENEMY_TIMER], KICK_GRACE_FRAMES
        jmp  .done

.not_still:
        mov  ax, [bx+ENEMY_Y]           ; the enemy's top, whole pixels
        mov  al, ah
        mov  ah, 0
        push ax
        call StompOrHurt                ; Module 10: AX = 1 stomp, 0 hurt
        cmp  ax, 0
        je   .hurt

        cmp  byte [bx+ENEMY_STATE], ENEMY_STATE_SHELL_SLIDE
        je   .stop_shell
        cmp  byte [bx+ENEMY_TYPE], ENEMY_GOOMBA
        je   .flatten
        mov  byte [bx+ENEMY_STATE], ENEMY_STATE_SHELL_STILL ; Koopa -> shell
        mov  word [bx+ENEMY_TIMER], KICK_GRACE_FRAMES
        jmp  .scored
.flatten:
        mov  byte [bx+ENEMY_STATE], ENEMY_STATE_FLAT
        mov  word [bx+ENEMY_TIMER], FLAT_GOOMBA_TICKS
        jmp  .scored
.stop_shell:
        mov  byte [bx+ENEMY_STATE], ENEMY_STATE_SHELL_STILL
        mov  word [bx+ENEMY_TIMER], KICK_GRACE_FRAMES
.scored:
        call StompScore                 ; chain points (or 1-UP)
        call BounceHero
        jmp  .done

.hurt:
        call HurtHero

.done:
        pop  dx
        pop  bx
        pop  ax
        pop  bp
        ret  2

; --------------------------------------------------------------------------
; Procedure : ResolveHeroEnemies
; Purpose   : Frame step 5 (enemy part): test Mario's hitbox against every
;             enemy with RectOverlap and call HeroTouchesEnemy for each one
;             he touches. Ignored: empty slots, WAITING enemies, flat
;             Goombas, and shells that are still in their grace time
;             (ENEMY_TIMER not 0).
; Inputs    : none (uses the hitbox variables of Mario, so the game loop
;             calls it after UpdateHero)
; Outputs   : see HeroTouchesEnemy
; Registers : none changed (AX, BX, CX, SI saved and restored)
; --------------------------------------------------------------------------
ResolveHeroEnemies:
        push ax
        push bx
        push cx
        push si

        mov  si, enemy_table
        mov  cx, MAX_ENEMIES
.next:
        cmp  byte [si+ENEMY_TYPE], ENEMY_NONE
        je   .skip
        cmp  byte [si+ENEMY_STATE], ENEMY_STATE_WAITING
        je   .skip
        cmp  byte [si+ENEMY_STATE], ENEMY_STATE_FLAT
        je   .skip
        cmp  word [si+ENEMY_TIMER], 0
        jne  .skip                      ; grace time: ignores Mario

        mov  ax, [hero_box_left]        ; rectangle 1: Mario's hitbox
        push ax
        mov  ax, [hero_box_top]
        push ax
        mov  ax, HITBOX_WIDTH
        push ax
        mov  ax, [hero_box_bottom]
        sub  ax, [hero_box_top]
        inc  ax                         ; height = bottom - top + 1
        push ax
        mov  ax, [si+ENEMY_X]           ; rectangle 2: the enemy
        push ax
        mov  bx, [si+ENEMY_Y]
        mov  bl, bh
        mov  bh, 0
        push bx
        mov  ax, TILE_SIZE
        push ax
        push ax
        call RectOverlap
        cmp  ax, 0
        je   .skip
        push si
        call HeroTouchesEnemy
.skip:
        add  si, ENEMY_RECORD_SIZE
        dec  cx
        jnz  .next

        pop  si
        pop  cx
        pop  bx
        pop  ax
        ret

; --------------------------------------------------------------------------
; Procedure : UpdateInvulnerability
; Purpose   : Frame step 6: count Mario's blink time down by one frame.
; Inputs    : none
; Outputs   : invuln_timer
; Registers : none changed
; --------------------------------------------------------------------------
UpdateInvulnerability:
        cmp  word [invuln_timer], 0
        je   .done
        dec  word [invuln_timer]
.done:
        ret

; --------------------------------------------------------------------------
; Procedure : DrawEnemies
; Purpose   : Frame step 9 (enemy part): draw every enemy that is on the
;             screen (WorldToScreenX, Module 6) with DrawSprite. All sprites
;             face right; an enemy that looks left is drawn mirrored.
; Inputs    : none
; Outputs   : the frame buffer
; Registers : none changed (AX, BX, CX, DX, SI saved and restored)
; --------------------------------------------------------------------------
DrawEnemies:
        push ax
        push bx
        push cx
        push dx
        push si

        mov  si, enemy_table
        mov  cx, MAX_ENEMIES
.next:
        cmp  byte [si+ENEMY_TYPE], ENEMY_NONE
        je   .skip
        mov  ax, [si+ENEMY_X]
        push ax
        call WorldToScreenX             ; AX = screen x, DX = 1 if visible
        cmp  dx, 0
        je   .skip
        push ax                         ; DrawSprite parameter 1: x
        mov  bx, [si+ENEMY_Y]
        mov  bl, bh
        mov  bh, 0
        push bx                         ; parameter 2: y

        mov  bx, sprite_goomba_walk     ; choose the sprite
        cmp  byte [si+ENEMY_TYPE], ENEMY_KOOPA
        je   .koopa
        cmp  byte [si+ENEMY_STATE], ENEMY_STATE_FLAT
        jne  .have_sprite
        mov  bx, sprite_goomba_flat
        jmp  .have_sprite
.koopa:
        mov  bx, sprite_koopa
        cmp  byte [si+ENEMY_STATE], ENEMY_STATE_SHELL_STILL
        je   .shell
        cmp  byte [si+ENEMY_STATE], ENEMY_STATE_SHELL_SLIDE
        jne  .have_sprite
.shell:
        mov  bx, sprite_shell
.have_sprite:
        push bx                         ; parameter 3: sprite address
        mov  ax, 0                      ; flags: facing right
        cmp  byte [si+ENEMY_DIR], FACING_LEFT
        jne  .flags_ready
        mov  ax, SPRITE_MIRROR          ; facing left: mirrored
.flags_ready:
        push ax                         ; parameter 4: flags
        call DrawSprite
.skip:
        add  si, ENEMY_RECORD_SIZE
        dec  cx
        jnz  .next

        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret