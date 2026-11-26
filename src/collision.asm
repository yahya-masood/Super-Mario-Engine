; collision.asm - owner: Sami Ahsan - stub, filled in later
; ==========================================================================
; FILE    : src/collision.asm
; OWNER   : Sami Ahsan (Module 10)
; PURPOSE : Collision detection (PDF Section 5.6, 5.9, Module 10).
;           Tile collision is done with GetTile (map.asm) on the WORKING map.
;           A tile is SOLID when its code is TILE_GROUND (1) to TILE_STAIR
;           (10): ground, brick, "?" blocks, empty block, pipes, stairs.
;           Coin (11) and flag pole (12) are not solid.
;
;           Mario's HITBOX is 12 pixels wide (2 pixels in from each side of
;           the 16 pixel sprite) and as tall as his form (16 or 32):
;             hero_box_left   = hero_x + 2          hero_box_right  = left + 11
;             hero_box_top    = whole pixels of hero_y
;             hero_box_bottom = top + height - 1    (last pixel row)
;           UpdateHeroBox calculates these four variables.
;
;           Order in a frame (PDF tip): move x, ResolveHeroX, move y,
;           ResolveHeroY. Mario never moves more than one tile per frame.
;           Parameters go on the stack (pushed left to right).
; ==========================================================================

; --------------------------------------------------------------------------
; Procedure : GetHeroHeight
; Purpose   : Height of Mario's sprite and hitbox: 16 (Small) or 32 (Super).
; Inputs    : none (reads form)
; Outputs   : AX = height in pixels
; Registers : only AX changed
; --------------------------------------------------------------------------
GetHeroHeight:
        mov  ax, SMALL_HEIGHT
        cmp  byte [form], FORM_SMALL
        je   .done
        mov  ax, SUPER_HEIGHT
.done:
        ret

; --------------------------------------------------------------------------
; Procedure : UpdateHeroBox
; Purpose   : Calculate the hitbox of Mario from hero_x, hero_y and his form.
; Inputs    : none
; Outputs   : hero_box_left, hero_box_right, hero_box_top, hero_box_bottom
; Registers : none changed (AX, BX saved and restored)
; --------------------------------------------------------------------------
UpdateHeroBox:
        push ax
        push bx

        mov  ax, [hero_x]               ; world x of the sprite's left edge
        add  ax, HITBOX_OFFSET_X        ; hitbox starts 2 pixels further right
        mov  [hero_box_left], ax
        add  ax, HITBOX_WIDTH-1         ; last pixel column of the hitbox
        mov  [hero_box_right], ax

        mov  ax, [hero_y]               ; 8.8 value: whole pixels are in AH
        mov  al, ah
        mov  ah, 0                      ; AX = whole pixels of y
        mov  [hero_box_top], ax
        mov  bx, ax                     ; BX = top
        call GetHeroHeight              ; AX = height
        add  ax, bx                     ; top + height
        dec  ax                         ; last pixel row = top + height - 1
        mov  [hero_box_bottom], ax

        pop  bx
        pop  ax
        ret

; --------------------------------------------------------------------------
; Procedure : SaveHeroFeet
; Purpose   : Store where Mario's feet are at the START of the frame, for
;             the stomp test of the NEXT enemy check ("in the previous frame
;             his feet were above ..."). feet = hero_y + height, in 8.8.
; Inputs    : none
; Outputs   : hero_prev_feet_y
; Registers : none changed (AX, BX saved and restored)
; --------------------------------------------------------------------------
SaveHeroFeet:
        push ax
        push bx

        call GetHeroHeight              ; AX = height
        mov  bx, ax
        mov  ah, bl                     ; AX = height * 256 (8.8 value)
        mov  al, 0
        add  ax, [hero_y]               ; + top = feet position, 8.8
        mov  [hero_prev_feet_y], ax

        pop  bx
        pop  ax
        ret

; --------------------------------------------------------------------------
; Procedure : TileInRange
; Purpose   : Is the tile at the world pixel (px, py) one of the codes
;             low to high? (Uses GetTile. Outside the map counts as sky.)
; Inputs    : push px, push py, push low, push high
;             [bp+10] = px   [bp+8] = py   [bp+6] = low   [bp+4] = high
; Outputs   : AX = 1 if low <= tile code <= high, otherwise 0
; Registers : only AX changed (BX, BP saved and restored)
; Note      : "ret 8" removes the 4 parameter words from the stack.
; --------------------------------------------------------------------------
TileInRange:
        push bp
        mov  bp, sp
        push bx

        mov  ax, [bp+10]
        push ax                         ; GetTile parameter 1: px
        mov  ax, [bp+8]
        push ax                         ; GetTile parameter 2: py
        call GetTile                    ; AX = tile code
        mov  bx, 0                      ; BX = result, assume "no"
        cmp  ax, [bp+6]                 ; tile code < low ?
        jb   .done
        cmp  ax, [bp+4]                 ; tile code > high ?
        ja   .done
        mov  bx, 1                      ; inside the range
.done:
        mov  ax, bx

        pop  bx
        pop  bp
        ret  8

; --------------------------------------------------------------------------
; Procedure : ColumnHasTile
; Purpose   : Look at the vertical line x = px along Mario's height, at his
;             top, middle and bottom pixel row. Is any of the three tiles
;             one of the codes low to high? (Three points are enough: Mario
;             is at most 32 pixels tall, so he touches at most 3 tile rows.)
; Inputs    : push px, push low, push high
;             [bp+8] = px   [bp+6] = low   [bp+4] = high
; Outputs   : AX = 1 if one of the three points is in the range, else 0
; Registers : only AX changed (BP saved and restored)
; Note      : needs the hitbox: call UpdateHeroBox first.
;             "ret 6" removes the 3 parameter words from the stack.
; --------------------------------------------------------------------------
ColumnHasTile:
        push bp
        mov  bp, sp

        mov  ax, [bp+8]                 ; ---- point 1: top row
        push ax
        mov  ax, [hero_box_top]
        push ax
        mov  ax, [bp+6]
        push ax
        mov  ax, [bp+4]
        push ax
        call TileInRange
        cmp  ax, 0
        jne  .done

        mov  ax, [bp+8]                 ; ---- point 2: middle row
        push ax
        mov  ax, [hero_box_top]
        add  ax, [hero_box_bottom]
        shr  ax, 1                      ; (top + bottom) / 2
        push ax
        mov  ax, [bp+6]
        push ax
        mov  ax, [bp+4]
        push ax
        call TileInRange
        cmp  ax, 0
        jne  .done

        mov  ax, [bp+8]                 ; ---- point 3: bottom row
        push ax
        mov  ax, [hero_box_bottom]
        push ax
        mov  ax, [bp+6]
        push ax
        mov  ax, [bp+4]
        push ax
        call TileInRange
.done:
        pop  bp
        ret  6

; --------------------------------------------------------------------------
; Procedure : RowHasTile
; Purpose   : Look at the horizontal line y = py at Mario's left and right
;             hitbox edge. Is one of the two tiles one of the codes
;             low to high? (His hitbox is 12 wide, so two points are enough.)
; Inputs    : push py, push low, push high
;             [bp+8] = py   [bp+6] = low   [bp+4] = high
; Outputs   : AX = 1 if one of the two points is in the range, else 0
; Registers : only AX changed (BP saved and restored)
; Note      : needs the hitbox: call UpdateHeroBox first.
;             "ret 6" removes the 3 parameter words from the stack.
; --------------------------------------------------------------------------
RowHasTile:
        push bp
        mov  bp, sp

        mov  ax, [hero_box_left]        ; ---- point 1: left edge
        push ax
        mov  ax, [bp+8]
        push ax
        mov  ax, [bp+6]
        push ax
        mov  ax, [bp+4]
        push ax
        call TileInRange
        cmp  ax, 0
        jne  .done

        mov  ax, [hero_box_right]       ; ---- point 2: right edge
        push ax
        mov  ax, [bp+8]
        push ax
        mov  ax, [bp+6]
        push ax
        mov  ax, [bp+4]
        push ax
        call TileInRange
.done:
        pop  bp
        ret  6

; --------------------------------------------------------------------------
; Procedure : ResolveHeroX
; Purpose   : Horizontal tile collision, called right after MoveHeroX.
;             Moving right: a solid tile at the right edge means a wall.
;             Moving left : a solid tile at the left edge means a wall.
;             Then Mario is placed against the wall, hero_x_frac = 0 and
;             hero_vx = 0 (PDF 5.6 "Wall in front").
; Inputs    : none
; Outputs   : hero_x, hero_x_frac, hero_vx
; Registers : none changed (AX saved and restored)
; Logic     : "AND 0FFF0h" clears the low 4 bits, so a pixel position becomes
;             the left edge of its tile (a multiple of 16).
; --------------------------------------------------------------------------
ResolveHeroX:
        push ax

        call UpdateHeroBox
        cmp  word [hero_vx], 0
        je   .done                      ; not moving sideways: nothing to do
        jl   .moving_left

        mov  ax, [hero_box_right]       ; ---- moving right
        push ax
        mov  ax, TILE_GROUND
        push ax
        mov  ax, TILE_STAIR
        push ax
        call ColumnHasTile
        cmp  ax, 0
        je   .done                      ; free: no wall
        mov  ax, [hero_box_right]
        and  ax, 0FFF0h                 ; left edge of the wall tile
        sub  ax, HITBOX_OFFSET_X+HITBOX_WIDTH ; sprite x so that box right =
        mov  [hero_x], ax               ; wall - 1
        jmp  .stop

.moving_left:
        mov  ax, [hero_box_left]        ; ---- moving left
        push ax
        mov  ax, TILE_GROUND
        push ax
        mov  ax, TILE_STAIR
        push ax
        call ColumnHasTile
        cmp  ax, 0
        je   .done
        mov  ax, [hero_box_left]
        and  ax, 0FFF0h                 ; left edge of the wall tile
        add  ax, TILE_SIZE              ; its right edge
        sub  ax, HITBOX_OFFSET_X        ; sprite x so that box left = that edge
        mov  [hero_x], ax

.stop:
        mov  byte [hero_x_frac], 0
        mov  word [hero_vx], 0
.done:
        pop  ax
        ret

; --------------------------------------------------------------------------
; Procedure : ResolveHeroY
; Purpose   : Vertical tile collision, called right after MoveHeroY.
;             - on_ground is set to 0 and head_hit to 0 first.
;             - Moving up (vy < 0): a solid tile at the head is a HEAD HIT.
;               Mario's top is put under that tile, vy = 0, and the hit is
;               reported in head_hit, head_hit_x (the horizontal centre of
;               his head) and head_hit_y, for Module 12 (block trigger).
;             - Otherwise (falling or standing): a solid tile in the pixel
;               row just BELOW his feet means he stands on it. He is put on
;               top of the tile, vy = 0, on_ground = 1 and stomp_chain = 0.
;               (Looking one row below the feet keeps on_ground = 1 on
;               every frame while he stands, so he can jump at any time.)
; Inputs    : none
; Outputs   : hero_y, hero_vy, on_ground, stomp_chain, head_hit, head_hit_x,
;             head_hit_y, and the hitbox variables
; Registers : none changed (AX, BX saved and restored)
; --------------------------------------------------------------------------
ResolveHeroY:
        push ax
        push bx

        call UpdateHeroBox
        mov  byte [on_ground], 0
        mov  byte [head_hit], 0
        cmp  word [hero_vy], 0
        jl   .rising

        mov  bx, [hero_box_bottom]      ; ---- falling or standing
        inc  bx                         ; BX = first pixel row below his feet
        push bx
        mov  ax, TILE_GROUND
        push ax
        mov  ax, TILE_STAIR
        push ax
        call RowHasTile
        cmp  ax, 0
        je   .done                      ; nothing solid below: in the air
        and  bx, 0FFF0h                 ; BX = top edge of the tile below
        call GetHeroHeight              ; AX = height
        sub  bx, ax                     ; BX = new top of Mario
        mov  ah, bl                     ; hero_y = whole pixels in the high byte
        mov  al, 0
        mov  [hero_y], ax
        mov  word [hero_vy], 0
        mov  byte [on_ground], 1
        mov  byte [stomp_chain], 0      ; landing ends the stomp chain
        jmp  .done

.rising:
        mov  ax, [hero_box_top]         ; ---- moving up
        push ax
        mov  ax, TILE_GROUND
        push ax
        mov  ax, TILE_STAIR
        push ax
        call RowHasTile
        cmp  ax, 0
        je   .done                      ; nothing solid at his head
        mov  byte [head_hit], 1         ; report the head hit
        mov  ax, [hero_box_left]
        add  ax, [hero_box_right]
        shr  ax, 1                      ; horizontal centre of the head
        mov  [head_hit_x], ax
        mov  ax, [hero_box_top]
        mov  [head_hit_y], ax           ; a pixel row inside the tile he hit
        and  ax, 0FFF0h                 ; top edge of that tile
        add  ax, TILE_SIZE              ; its bottom edge
        mov  ah, al                     ; hero_y = whole pixels in the high byte
        mov  al, 0
        mov  [hero_y], ax
        mov  word [hero_vy], 0          ; he starts falling

.done:
        call UpdateHeroBox              ; hitbox of the final position
        pop  bx
        pop  ax
        ret

; --------------------------------------------------------------------------
; Procedure : CheckHeroPit
; Purpose   : Pit test (PDF 5.6): the top of Mario is at y >= 192.
; Inputs    : none
; Outputs   : AX = 1 if Mario fell into a pit, otherwise 0
; Registers : only AX changed
; Note      : hero_y is 8.8, so its whole pixels are the HIGH byte, which is
;             the byte at address hero_y + 1. The frame loop must stop
;             calling UpdateHero after a pit death (state DYING).
; --------------------------------------------------------------------------
CheckHeroPit:
        mov  ax, 0
        cmp  byte [hero_y+1], PIT_Y     ; whole pixels of y >= 192 ?
        jb   .done
        mov  ax, 1
.done:
        ret

; --------------------------------------------------------------------------
; Procedure : CheckHeroFlag
; Purpose   : Does Mario touch the flag pole (tile TILE_FLAG)? If yes, also
;             tell the map row of his bottom edge, for the points of 5.4:
;             rows 2-3 = 5000, 4 = 2000, 5 = 800, 6-7 = 400, 8 = 100.
; Inputs    : none
; Outputs   : AX = 0 if he does not touch the pole, otherwise the map row of
;             his bottom pixel row (2 or more; 9 counts as the bottom zone)
; Registers : only AX changed
; --------------------------------------------------------------------------
CheckHeroFlag:
        call UpdateHeroBox

        mov  ax, [hero_box_left]        ; left edge of the hitbox
        push ax
        mov  ax, TILE_FLAG
        push ax
        push ax                         ; low = high = TILE_FLAG
        call ColumnHasTile
        cmp  ax, 0
        jne  .touching

        mov  ax, [hero_box_right]       ; right edge of the hitbox
        push ax
        mov  ax, TILE_FLAG
        push ax
        push ax
        call ColumnHasTile
        cmp  ax, 0
        je   .done                      ; AX = 0: not touching
.touching:
        mov  ax, [hero_box_bottom]
        shr  ax, 1                      ; divide by 16 (4 shifts): map row
        shr  ax, 1
        shr  ax, 1
        shr  ax, 1
.done:
        ret

; --------------------------------------------------------------------------
; Procedure : RectOverlap
; Purpose   : Do two rectangles overlap? They overlap when, on both axes,
;             each one starts before the other one ends:
;               x1 < x2+w2  and  x2 < x1+w1  and  y1 < y2+h2  and  y2 < y1+h1
; Inputs    : push x1, y1, w1, h1, x2, y2, w2, h2 (in this order)
;             [bp+18]=x1 [bp+16]=y1 [bp+14]=w1 [bp+12]=h1
;             [bp+10]=x2 [bp+8]=y2  [bp+6]=w2  [bp+4]=h2
; Outputs   : AX = 1 if they overlap, otherwise 0
; Registers : only AX changed (BX, BP saved and restored)
; Note      : signed compares, so a position above the screen (negative)
;             also works. "ret 16" removes the 8 parameter words.
; --------------------------------------------------------------------------
RectOverlap:
        push bp
        mov  bp, sp
        push bx

        mov  ax, [bp+18]                ; x1
        mov  bx, [bp+10]
        add  bx, [bp+6]                 ; x2 + w2
        cmp  ax, bx
        jge  .no                        ; x1 >= x2+w2: 1 is right of 2

        mov  ax, [bp+10]                ; x2
        mov  bx, [bp+18]
        add  bx, [bp+14]                ; x1 + w1
        cmp  ax, bx
        jge  .no                        ; x2 >= x1+w1: 2 is right of 1

        mov  ax, [bp+16]                ; y1
        mov  bx, [bp+8]
        add  bx, [bp+4]                 ; y2 + h2
        cmp  ax, bx
        jge  .no                        ; 1 is below 2

        mov  ax, [bp+8]                 ; y2
        mov  bx, [bp+16]
        add  bx, [bp+12]                ; y1 + h1
        cmp  ax, bx
        jge  .no                        ; 2 is below 1

        mov  ax, 1                      ; all four tests passed: overlap
        jmp  .done
.no:
        mov  ax, 0
.done:
        pop  bx
        pop  bp
        ret  16

; --------------------------------------------------------------------------
; Procedure : StompOrHurt
; Purpose   : The stomp test of PDF 5.6, for an enemy that Mario already
;             overlaps. It is a STOMP when
;               - Mario is moving down (hero_vy > 0), and
;               - in the previous frame his feet were not below the upper
;                 half of the enemy (previous feet <= enemy top + 8).
;             Otherwise Mario is hurt (side or bottom contact).
; Inputs    : push enemy_y (top of the enemy, whole pixels; enemies are
;             16 pixels tall)
;             [bp+4] = enemy_y
; Outputs   : AX = 1 for a stomp, 0 for a hurt contact
; Registers : only AX changed (BX, BP saved and restored)
; Note      : uses hero_vy and hero_prev_feet_y (saved by SaveHeroFeet at
;             the start of the frame). "ret 2" removes the parameter.
; --------------------------------------------------------------------------
StompOrHurt:
        push bp
        mov  bp, sp
        push bx

        mov  ax, 0                      ; assume: hurt
        cmp  word [hero_vy], 0
        jle  .done                      ; not moving down: hurt

        mov  bx, [hero_prev_feet_y]     ; 8.8: whole pixels are in BH
        mov  bl, bh
        mov  bh, 0                      ; BX = previous feet, whole pixels
        mov  ax, [bp+4]                 ; enemy top
        add  ax, TILE_SIZE/2            ; boundary of the enemy's upper half
        cmp  bx, ax
        jg   .hurt_now                  ; feet were lower than that: hurt
        mov  ax, 1                      ; stomp
        jmp  .done
.hurt_now:
        mov  ax, 0
.done:
        pop  bx
        pop  bp
        ret  2