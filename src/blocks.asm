; blocks.asm - owner: Yahya Masood - stub, filled in later
; ==========================================================================
; FILE    : src/blocks.asm
; OWNER   : Yahya Masood (Module 12)
; PURPOSE : Blocks, coins and power-ups (PDF Section 5.9, Module 12).
;           - Mario's head hits a block from below (head_hit, head_hit_x and
;             head_hit_y are reported by ResolveHeroY, Module 10):
;               brick        Small Mario: nothing. Super Mario: the brick
;                            breaks (tile becomes sky) and gives 50 points.
;               "?" coin     becomes an empty block, +1 coin, 200 points and
;                            a coin pops up above the block.
;               "?" mushroom becomes an empty block and a mushroom appears
;                            on top of it.
;           - Coins in the map (TILE_COIN): Mario touches one, it disappears,
;             +1 coin, 200 points. 100 coins = +1 life and coins start at 0.
;           - Mushroom: walks right at SPEED_MUSHROOM, turns at walls, falls
;             off ledges. Mario touches it: 1000 points, Small becomes Super.
;           The mushrooms use the SAME 12 byte record layout as the enemies
;           (ENEMY_TYPE, ENEMY_X ...), but live in their own table
;           (mushroom_table, data_game.asm), so Module 11 is not touched and
;           the enemy procedures (EnemyFalls, StepEnemy) can be reused.
;           Per frame the game loop calls:
;             HandleHeadHit, CollectCoins       after UpdateHero
;             UpdateMushrooms                   after UpdateEnemies
;             ResolveHeroMushrooms              after ResolveHeroEnemies
;             UpdatePopCoin                     with the other timers
;             DrawPopCoin, DrawMushrooms        when the frame is drawn
;           Parameters go on the stack (pushed left to right).
;           Only basic 8086 instructions are used.
; ==========================================================================

; --------------------------------------------------------------------------
; Procedure : ResetBlockItems
; Purpose   : Remove all mushrooms and the coin pop-up (new life, new game).
;             The blocks themselves come back with ResetMap.
; Inputs    : none
; Outputs   : mushroom_table, coin_pop_timer
; Registers : none changed (CX, SI saved and restored)
; --------------------------------------------------------------------------
ResetBlockItems:
        push cx
        push si

        mov  si, mushroom_table
        mov  cx, MAX_MUSHROOMS
.clear:
        mov  byte [si+ENEMY_TYPE], ENEMY_NONE   ; empty slot
        add  si, ENEMY_RECORD_SIZE
        dec  cx
        jnz  .clear
        mov  byte [coin_pop_timer], 0

        pop  si
        pop  cx
        ret

; --------------------------------------------------------------------------
; Procedure : AddCoin
; Purpose   : One more coin (PDF 5.4). At COINS_FOR_LIFE (100) coins the
;             counter goes back to 0 and Mario gets one extra life (never
;             more than MAX_LIVES).
; Inputs    : none
; Outputs   : coins, lives
; Registers : none changed (flags only)
; --------------------------------------------------------------------------
AddCoin:
        inc  byte [coins]
        cmp  byte [coins], COINS_FOR_LIFE
        jb   .done                      ; fewer than 100 coins
        mov  byte [coins], 0            ; 100 coins: start again at 0
        cmp  byte [lives], MAX_LIVES
        jae  .done                      ; already the maximum
        inc  byte [lives]               ; 1-UP
.done:
        ret

; --------------------------------------------------------------------------
; Procedure : SpawnMushroom
; Purpose   : Put a mushroom into the first free record of mushroom_table.
;             It walks to the right. If the table is full, nothing happens.
; Inputs    : push x, push y   (world pixels: left edge and TOP of the mushroom)
;             [bp+6] = x   [bp+4] = y
; Outputs   : mushroom_table
; Registers : none changed (AX, CX, SI, BP saved and restored)
; Note      : ENEMY_Y is 8.8, so the whole pixels go into the high byte.
;             "ret 4" removes the 2 parameter words from the stack.
; --------------------------------------------------------------------------
SpawnMushroom:
        push bp
        mov  bp, sp
        push ax
        push cx
        push si

        mov  si, mushroom_table
        mov  cx, MAX_MUSHROOMS
.find:
        cmp  byte [si+ENEMY_TYPE], ENEMY_NONE
        je   .use                       ; free record found
        add  si, ENEMY_RECORD_SIZE
        dec  cx
        jnz  .find
        jmp  .done                      ; no free record
.use:
        mov  byte [si+ENEMY_TYPE], ENEMY_MUSHROOM
        mov  byte [si+ENEMY_STATE], ENEMY_STATE_WALKING
        mov  ax, [bp+6]
        mov  [si+ENEMY_X], ax
        mov  byte [si+ENEMY_XFRAC], 0
        mov  byte [si+ENEMY_DIR], FACING_RIGHT
        mov  ax, [bp+4]                 ; whole pixels of y
        mov  ah, al                     ; 8.8: whole pixels in the high byte
        mov  al, 0
        mov  [si+ENEMY_Y], ax
        mov  word [si+ENEMY_SPEED], SPEED_MUSHROOM
        mov  word [si+ENEMY_TIMER], 0
.done:
        pop  si
        pop  cx
        pop  ax
        pop  bp
        ret  4

; --------------------------------------------------------------------------
; Procedure : TryHitBlockAt
; Purpose   : Mario's head hit a solid tile. Look at the tile in the column
;             of the world x px and in the row of head_hit_y. If it is a
;             brick or a "?" block, it reacts (see the top of this file).
; Inputs    : push px
;             [bp+4] = px
; Outputs   : AX = 1 if the tile was a brick or "?" block, otherwise 0;
;             working_map, score, coins, lives, mushroom_table, coin_pop_*
; Registers : only AX changed (BX, CX, DX, BP saved and restored)
; Logic     : CX = column, DX = row, BX = offset in working_map
; Note      : "ret 2" removes the 1 parameter word from the stack.
; --------------------------------------------------------------------------
TryHitBlockAt:
        push bp
        mov  bp, sp
        push bx
        push cx
        push dx

        mov  cx, [bp+4]                 ; CX = column = px / 16
        shr  cx, 1
        shr  cx, 1
        shr  cx, 1
        shr  cx, 1
        mov  dx, [head_hit_y]           ; DX = row = py / 16
        shr  dx, 1
        shr  dx, 1
        shr  dx, 1
        shr  dx, 1
        mov  ax, 0                      ; result so far: no block
        cmp  cx, LEVEL_COLS
        jae  .done                      ; outside the map
        cmp  dx, LEVEL_ROWS
        jae  .done

        mov  ax, dx                     ; offset = row * 60 + column
        mov  bl, LEVEL_COLS
        mul  bl                         ; AX = row * 60
        add  ax, cx
        mov  bx, ax                     ; BX = offset
        mov  al, [working_map+bx]       ; AL = tile code

        cmp  al, TILE_BRICK
        je   .brick
        cmp  al, TILE_QBLOCK_COIN
        je   .coin_block
        cmp  al, TILE_QBLOCK_MUSH
        je   .mush_block
        mov  ax, 0                      ; another tile: not a block
        jmp  .done

.brick:
        mov  ax, 1                      ; it was a block
        cmp  byte [form], FORM_SUPER
        jne  .done                      ; Small Mario: the brick stays
        mov  byte [working_map+bx], TILE_SKY    ; Super Mario breaks it
        mov  ax, BRICK_POINTS
        push ax
        call AddScore
        mov  ax, 1
        jmp  .done

.coin_block:
        mov  byte [working_map+bx], TILE_EMPTY_BLOCK
        call AddCoin
        mov  ax, COIN_POINTS
        push ax
        call AddScore
        mov  ax, cx                     ; pop-up x = column * 16
        shl  ax, 1
        shl  ax, 1
        shl  ax, 1
        shl  ax, 1
        mov  [coin_pop_x], ax
        mov  ax, dx                     ; pop-up y = (row - 1) * 16,
        dec  ax                         ; the tile above the block
        shl  ax, 1
        shl  ax, 1
        shl  ax, 1
        shl  ax, 1
        mov  [coin_pop_y], ax
        mov  byte [coin_pop_timer], COIN_POP_FRAMES
        mov  ax, 1
        jmp  .done

.mush_block:
        mov  byte [working_map+bx], TILE_EMPTY_BLOCK
        mov  ax, cx                     ; SpawnMushroom parameter 1:
        shl  ax, 1                      ; x = column * 16
        shl  ax, 1
        shl  ax, 1
        shl  ax, 1
        push ax
        mov  ax, dx                     ; parameter 2: y = (row - 1) * 16,
        dec  ax                         ; standing on top of the block
        shl  ax, 1
        shl  ax, 1
        shl  ax, 1
        shl  ax, 1
        push ax
        call SpawnMushroom
        mov  ax, 1

.done:
        pop  dx
        pop  cx
        pop  bx
        pop  bp
        ret  2

; --------------------------------------------------------------------------
; Procedure : HandleHeadHit
; Purpose   : Frame step after UpdateHero. If Mario's head hit a solid tile
;             this frame (head_hit = 1), find the block he hit. His hitbox is
;             12 wide and a tile is 16 wide, so the head can touch the tile
;             beside the centre: try the centre first, then the left edge,
;             then the right edge. Only one block reacts.
; Inputs    : none (reads head_hit, head_hit_x, hero_box_left/right)
; Outputs   : see TryHitBlockAt
; Registers : none changed (AX saved and restored)
; --------------------------------------------------------------------------
HandleHeadHit:
        push ax

        cmp  byte [head_hit], 0
        je   .done                      ; no head hit this frame

        mov  ax, [head_hit_x]           ; centre of the head
        push ax
        call TryHitBlockAt
        cmp  ax, 0
        jne  .done

        mov  ax, [hero_box_left]        ; left edge of the head
        push ax
        call TryHitBlockAt
        cmp  ax, 0
        jne  .done

        mov  ax, [hero_box_right]       ; right edge of the head
        push ax
        call TryHitBlockAt
.done:
        pop  ax
        ret

; --------------------------------------------------------------------------
; Procedure : CollectCoins
; Purpose   : Take every coin tile (TILE_COIN) that touches Mario's hitbox:
;             the tile becomes sky, +1 coin (AddCoin, 100 coins = 1-UP) and
;             COIN_POINTS points. Every tile from the hitbox's first to last
;             column and from its first to last row is looked at.
; Inputs    : none (uses the hitbox variables, so call it after UpdateHero)
; Outputs   : working_map, coins, lives, score
; Registers : none changed (AX, BX, CX, DX, SI, DI saved and restored)
; Logic     : DX = row, CX = last row, SI = column, DI = last column
; --------------------------------------------------------------------------
CollectCoins:
        push ax
        push bx
        push cx
        push dx
        push si
        push di

        mov  dx, [hero_box_top]         ; DX = first row = top / 16
        shr  dx, 1
        shr  dx, 1
        shr  dx, 1
        shr  dx, 1
        mov  cx, [hero_box_bottom]      ; CX = last row = bottom / 16
        shr  cx, 1
        shr  cx, 1
        shr  cx, 1
        shr  cx, 1
        mov  di, [hero_box_right]       ; DI = last column = right / 16
        shr  di, 1
        shr  di, 1
        shr  di, 1
        shr  di, 1
.row_loop:
        cmp  dx, LEVEL_ROWS
        jae  .done                      ; below or above the map: stop
        mov  si, [hero_box_left]        ; SI = first column = left / 16
        shr  si, 1
        shr  si, 1
        shr  si, 1
        shr  si, 1
.col_loop:
        mov  ax, dx                     ; offset = row * 60 + column
        mov  bl, LEVEL_COLS
        mul  bl                         ; AX = row * 60
        add  ax, si
        mov  bx, ax                     ; BX = offset in working_map
        cmp  byte [working_map+bx], TILE_COIN
        jne  .next_col
        mov  byte [working_map+bx], TILE_SKY    ; the coin is taken
        call AddCoin
        mov  ax, COIN_POINTS
        push ax
        call AddScore
.next_col:
        inc  si
        cmp  si, di
        jbe  .col_loop                  ; more columns in this row
        inc  dx
        cmp  dx, cx
        jbe  .row_loop                  ; more rows
.done:
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

; --------------------------------------------------------------------------
; Procedure : UpdateOneMushroom
; Purpose   : One frame of one mushroom: removed when it is more than 32
;             pixels left of the screen or has fallen below the map;
;             otherwise gravity (EnemyFalls) and, when it stands, one step
;             forward (StepEnemy: turns round at walls, never at ledges).
; Inputs    : push record address
;             [bp+4] = record
; Outputs   : the record
; Registers : none changed (AX, BX, DX, BP saved and restored)
; Note      : "ret 2" removes the 1 parameter word from the stack.
; --------------------------------------------------------------------------
UpdateOneMushroom:
        push bp
        mov  bp, sp
        push ax
        push bx
        push dx

        mov  bx, [bp+4]                 ; BX = record
        mov  ax, [bx+ENEMY_X]
        push ax
        call WorldToScreenX             ; AX = screen x
        cmp  ax, -2*TILE_SIZE
        jl   .remove                    ; far left of the screen
        cmp  byte [bx+ENEMY_Y+1], VISIBLE_HEIGHT
        jae  .remove                    ; fell below the map

        push bx
        call EnemyFalls                 ; AX = 1 if it stands on something
        cmp  ax, 0
        je   .done                      ; in the air: it falls, no walking
        push bx                         ; StepEnemy: record,
        mov  ax, 0
        push ax                         ;   edge_check = 0 (walks off ledges),
        push ax                         ;   others_check = 0
        call StepEnemy
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
; Procedure : UpdateMushrooms
; Purpose   : Update every mushroom record (skipping empty slots).
; Inputs    : none
; Outputs   : mushroom_table
; Registers : none changed (CX, SI saved and restored)
; --------------------------------------------------------------------------
UpdateMushrooms:
        push cx
        push si

        mov  si, mushroom_table
        mov  cx, MAX_MUSHROOMS
.next:
        cmp  byte [si+ENEMY_TYPE], ENEMY_NONE
        je   .skip
        push si
        call UpdateOneMushroom
.skip:
        add  si, ENEMY_RECORD_SIZE
        dec  cx
        jnz  .next

        pop  si
        pop  cx
        ret

; --------------------------------------------------------------------------
; Procedure : CollectMushroom
; Purpose   : Mario touches a mushroom: it disappears, +MUSHROOM_POINTS
;             points. Small Mario becomes Super (form and hp change together).
;             His FEET STAY WHERE THEY ARE, so his top moves up by 16 pixels
;             (the opposite of HurtHero). Super Mario only gets the points.
; Inputs    : push record address
;             [bp+4] = record
; Outputs   : record, score, form, hp, hero_y, hitbox variables
; Registers : none changed (AX, BX, BP saved and restored)
; Note      : "ret 2" removes the 1 parameter word from the stack.
; --------------------------------------------------------------------------
CollectMushroom:
        push bp
        mov  bp, sp
        push ax
        push bx

        mov  bx, [bp+4]                 ; BX = record
        mov  byte [bx+ENEMY_TYPE], ENEMY_NONE   ; the mushroom is gone
        mov  ax, MUSHROOM_POINTS
        push ax
        call AddScore

        cmp  byte [form], FORM_SMALL
        jne  .done                      ; already Super: only the points
        mov  byte [form], FORM_SUPER
        mov  byte [hp], HP_SUPER
        sub  word [hero_y], (SUPER_HEIGHT-SMALL_HEIGHT)*256 ; feet stay fixed
        call UpdateHeroBox              ; the hitbox is now 32 tall
.done:
        pop  bx
        pop  ax
        pop  bp
        ret  2

; --------------------------------------------------------------------------
; Procedure : ResolveHeroMushrooms
; Purpose   : Test Mario's hitbox against every mushroom with RectOverlap
;             and call CollectMushroom for each one he touches.
; Inputs    : none
; Outputs   : see CollectMushroom
; Registers : none changed (AX, BX, CX, SI saved and restored)
; --------------------------------------------------------------------------
ResolveHeroMushrooms:
        push ax
        push bx
        push cx
        push si

        call UpdateHeroBox              ; make sure the hitbox is current
        mov  si, mushroom_table
        mov  cx, MAX_MUSHROOMS
.next:
        cmp  byte [si+ENEMY_TYPE], ENEMY_NONE
        je   .skip

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
        mov  ax, [si+ENEMY_X]           ; rectangle 2: the mushroom
        push ax
        mov  bx, [si+ENEMY_Y]
        mov  bl, bh
        mov  bh, 0                      ; whole y
        push bx
        mov  ax, TILE_SIZE
        push ax
        push ax
        call RectOverlap
        cmp  ax, 0
        je   .skip
        push si
        call CollectMushroom
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
; Procedure : UpdatePopCoin
; Purpose   : Count the coin pop-up time down by one frame.
; Inputs    : none
; Outputs   : coin_pop_timer
; Registers : none changed
; --------------------------------------------------------------------------
UpdatePopCoin:
        cmp  byte [coin_pop_timer], 0
        je   .done
        dec  byte [coin_pop_timer]
.done:
        ret

; --------------------------------------------------------------------------
; Procedure : DrawPopCoin
; Purpose   : Draw the coin that jumps out of a "?" block. It rises
;             COIN_POP_RISE pixels per frame while coin_pop_timer counts down.
; Inputs    : none
; Outputs   : the frame buffer
; Registers : none changed (AX, BX saved and restored)
; --------------------------------------------------------------------------
DrawPopCoin:
        push ax
        push bx

        cmp  byte [coin_pop_timer], 0
        je   .done                      ; no coin on its way

        mov  ax, [coin_pop_x]           ; DrawSprite parameter 1:
        sub  ax, [camera_x]             ; screen x = world x - camera_x
        push ax
        mov  al, COIN_POP_FRAMES        ; frames since the hit =
        sub  al, [coin_pop_timer]       ; COIN_POP_FRAMES - timer
        mov  ah, 0
        mov  bl, COIN_POP_RISE
        mul  bl                         ; AX = pixels risen so far
        mov  bx, [coin_pop_y]
        sub  bx, ax                     ; parameter 2: screen y
        push bx
        mov  ax, sprite_coin
        push ax                         ; parameter 3: sprite address
        mov  ax, 0
        push ax                         ; parameter 4: flags
        call DrawSprite
.done:
        pop  bx
        pop  ax
        ret

; --------------------------------------------------------------------------
; Procedure : DrawMushrooms
; Purpose   : Draw every mushroom that is on the screen (WorldToScreenX).
; Inputs    : none
; Outputs   : the frame buffer
; Registers : none changed (AX, BX, CX, DX, SI saved and restored)
; --------------------------------------------------------------------------
DrawMushrooms:
        push ax
        push bx
        push cx
        push dx
        push si

        mov  si, mushroom_table
        mov  cx, MAX_MUSHROOMS
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
        mov  ax, sprite_mushroom
        push ax                         ; parameter 3: sprite address
        mov  ax, 0
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