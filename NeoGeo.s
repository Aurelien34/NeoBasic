	include "inc/basic.inc"
	include "inc/define.inc"
	include "inc/trace.inc"

    global ON_RESET_NEOGEO, SETUP_NEOGEO
    global VBLANK, HBLANK
	global HW_TRAP15_GETBYTE, HW_TRAP15_PUTBYTE, HW_TRAP15_STATUS
	global fix_layer_cls, fix_locate_cursor_position
	global BasicNeo_cursor_blink_start, BasicNeo_cursor_blink_loop, BasicNeo_cursor_blink_stop

    section header
	; Magic word - 8 bytes
	dc.b "BricoNeo"
	; Version - 4 bytes
	dc.l 0
	; Special modes
	dc.w BRICO_SPECIAL_FLAG_68K_SENDS_COMMANDS+BRICO_SPECIAL_FLAG_68K_REMOTE_KEYBOARD_MODE
	;dc.w BRICO_SPECIAL_FLAG_68K_SENDS_COMMANDS

	dc.b "EhBASIC NeoGeo"


	section	text

ON_RESET_NEOGEO
	* Initialize NeoGeo hardware and EhBASIC
	move #$2700,sr					; Supervisor mode + all interrupts disabled
	WatchDog 						; kick watchdog
	move.w	#7,(REG_IRQACK).l 		; ack all IRQs
	move #$2000,sr     				; Accept all interrupts (+Supervisor mode)
	
	rts

SETUP_NEOGEO
	; Keyboard initialization
	move.b BRICO_KEYBOARD_IN,d0
	move.b d0,keyboard_polling_index(a3)

	; Palette initialization
	jsr init_palette
	move.w #$f000,CurrentColorMask(a3)

	; Fix layer intialization
	jsr fix_layer_cls
	jsr fix_layer_show_snk

	move.b #NEOBASIC_INITIAL_POSITION_X,d0
	move.b #NEOBASIC_INITIAL_POSITION_Y,d1
	jsr fix_layer_locate

    rts

VBLANK
    move.w #4,REG_IRQACK
	WatchDog
	addq.b #1,CursorBlink_counter(a3)
	rte

HBLANK
	rte

* fn 5 - get byte (blocking). return: d1.b = character received
HW_TRAP15_GETBYTE

	; Wait for a key to be pressed
.wait_for_key
	move.b BRICO_KEYBOARD_IN,d1
	cmp.b keyboard_polling_index(a3),d1
	beq .wait_for_key

	; Store the polling index for the next call
	move.b d1,keyboard_polling_index(a3)

	; Get the key
	move.b BRICO_KEYBOARD_IN+1,d1

	RTE

* fn 6 - character out. in: d1.b = character to send
HW_TRAP15_PUTBYTE

	cmp.b #0,d1
	bne .continue
	rte

.continue
	move.b d1,d0
	;jsr put_byte_to_briconeo_terminal
	jsr put_byte_to_fix_layer

	RTE

* fn 7 - get status (non blocking). return: d1.b = 0 if none waiting, <>0 if
* a character is waiting
HW_TRAP15_STATUS

	move.b BRICO_KEYBOARD_IN,d1
	cmp.b keyboard_polling_index(a3),d1
	beq .nochar
	move.b #1,d1
	RTE
.nochar
	move.b #0,d1
	RTE


init_palette:
	move.b #0,REG_PALBANK0          ; Select first bank

	; Setup first palette
    move.l #PALETTE_RAM_START,a0
    move.w #16-1,d7
	move.l #.fix_palette_data,a1
.loopclear1:
    move.w (a1)+,(a0)+
    dbra d7,.loopclear1

	; Setup every first color of all palettes
    move.l #PALETTE_RAM_START+2,a0
    move.w #16*16-1,d7
	lea .fix_palette_data(pc),a1
.loopclear2:
    move.w (a1)+,(a0)+
	move.w #$0,(a0)+
	add.l #(16-2)*2,a0
    dbra d7,.loopclear2

    move.w #$8000,PALETTE_RAM_START ; pure black background
    move.w #$8000,PALETTE_BACKDROP

	rts
.fix_palette_data:
	dc.w $8000, $900F, $A0F0, $A0FF, $CF00, $CF0F, $DFF0, $DFFF, $0444, $100F, $20F0, $30FF, $4F00, $5F0F, $6FF0, $7FFF

fix_layer_cls:
    movem.l d7,-(sp)

    ; Set VRAM start address
    move.w #VRAM_ADDRESS_FIX,REG_VRAMADD
    ; Increment after each write
    move.w #1,REG_VRAMMOD
    ; Loop counter
    move.w #1279,d7
	move.b #' ',d0
	jsr get_tile_address_for_char
.drawLoop
    move.w d0,REG_VRAMRW
    dbra d7,.drawLoop
	move.w #$20,REG_VRAMMOD

    movem.l (sp)+,d7
	rts

; Display the SNK logo in the top right corner
fix_layer_show_snk
    movem.l d0/d6-d7/a0,-(sp)
	move.w #VRAM_ADDRESS_FIX+NEOBASIC_FIX_TOP_ROW+1+2*(NEOBASIC_FIX_WIDTH-10+NEOBASIC_FIX_LEFT_COLUMN)*16,d0
	lea .logodata(pc),a0
	move.w #3-1,d7
.loopy
	move.w #10-1,d6
    move.w d0,REG_VRAMADD
.loopx
	move.w (a0)+,REG_VRAMRW
	dbra d6,.loopx
	addq.w #1,d0
	dbra d7,.loopy
    movem.l (sp)+,d0/d6-d7/a0
	rts
.logodata
	dc.w $200, $201, $202, $203, $204, $205, $206, $207, $208, $209
	dc.w $20a, $20b, $20c, $20d, $20e, $20f, $214, $215, $216, $217
	dc.w $218, $219, $21a, $21b, $21c, $21d, $21e, $21f, $240, $25e

; Input: d0.b = character to display
; Output: d0.w = address of the tile in the tilemap
get_tile_address_for_char:
	
	and.w #$00ff,d0
	or.w CurrentColorMask(a3),d0 ; Apply current color

	rts
.char_tile_mapping

; Input: (x,y) in (d0.b,d1.b)
fix_layer_locate:

	; Move to the display area
	addi.b #NEOBASIC_FIX_LEFT_COLUMN,d0
	andi.w #$00ff,d0
	addi.b #NEOBASIC_FIX_TOP_ROW,d1
	andi.w #$00ff,d1

	; Calculate the tilemap address
	lsl.w #5,d0 ; 32 rows before moving to the next column
	add.w d1,d0 ; add row offset
	add.w #VRAM_ADDRESS_FIX,d0 ; add the fix layer address offset

	; Send to VRAM Address register
	move.w d0,REG_VRAMADD

	rts

; Input: d0.b = character to display
fix_layer_put_char:
	jsr get_tile_address_for_char
	move.w d0,REG_VRAMRW
	rts

; Input: d0.b = character to display
put_byte_to_briconeo_terminal:
    movem.l d0-d2/a0,-(sp)
	move.b d0,d2
    brico_command_header_print_text ; Send text write command
	and.w #$00ff,d2
    move.w d2,d0 
	jsr port_write_d0 ; Pass command argument
    brico_send_eot  ; End of command
    movem.l (sp)+,d0-d2/a0
	rts

; Input: d0.b = character to display
put_byte_to_fix_layer;
	; Check DEL
	cmp.b #$08,d0
	bne .no_del
	bsr key_pressed_del
	jmp .visible_character_processed

.no_del:
	; Check CR
	cmp.b #$0d,d0
	bne .not_cr
	move.b #0,CursorX(a3)
	bsr fix_locate_cursor_position
	jmp .visible_character_processed

.not_cr:
	; Check LF
	cmp.b #$0a,d0
	bne .not_lf
	addq.b #1,CursorY(a3)
	jsr fix_locate_cursor_position
	jmp .visible_character_processed

.not_lf:

	jsr fix_layer_put_char

	; Increment cursor coordinate
	addq.b #1,CursorX(a3)

.visible_character_processed:

	; Check end of line
	cmp.b #NEOBASIC_FIX_WIDTH,CursorX(a3)
	blt .no_wrap
	move.b #0,CursorX(a3)
	;addq.b #1,CursorY(a3) ; TODO: understand why this is not required!
	bsr fix_locate_cursor_position

.no_wrap:

	; check end of screen
	cmp.b #NEOBASIC_FIX_HEIGHT,CursorY(a3)
	blt .no_scroll
	subq.b #1,CursorY(a3)

	jsr fix_scroll_up

	bsr fix_locate_cursor_position

.no_scroll:

	rts

fix_scroll_up:
	movem d6-d7,-(sp)


	move.w #VRAM_ADDRESS_FIX,d1
	move.w #$7001,REG_VRAMADD
	move.w #2,REG_VRAMMOD
	move.w #1280-2,d7
.loop:
	move.w REG_VRAMRW,d0
	move.w d1,REG_VRAMADD
	move.w d0,REG_VRAMRW
	addq.w #1,d1
	dbra d7,.loop
	move.w #$20,REG_VRAMMOD

	move.w #VRAM_ADDRESS_FIX+NEOBASIC_FIX_TOP_ROW+NEOBASIC_FIX_HEIGHT-1,REG_VRAMADD
	move.w #39,d7
.loop2:
	move.w #' ',REG_VRAMRW
	nop
	nop
	dbra d7,.loop2

	move.w #VRAM_ADDRESS_FIX,d0
	move.w #NEOBASIC_FIX_TOP_ROW-1,d6
.loop3_1:
	move.w d0,REG_VRAMADD
	move.w #39,d7
.loop3_2:
	move.w #' ',REG_VRAMRW
	dbra d7,.loop3_2
	addi.w #1,d0
	dbra d6,.loop3_1

	movem (sp)+,d6-d7

	rts

key_pressed_del:
	; Check buffer size
	cmp.b #0,CursorX(a3)
	beq .left_border_reached
	subq.b #1,CursorX(a3)
	bsr fix_locate_cursor_position
	bra .delete_current_char

.left_border_reached:
	cmp.b #0,CursorY(a3)
	beq .delete_current_char

	subq.b #1,CursorY(a3)
	move.b #NEOBASIC_FIX_WIDTH-1,CursorX(a3)
	bsr fix_locate_cursor_position

.delete_current_char
	move #' ',REG_VRAMRW
	bsr fix_locate_cursor_position

	rts

; Position the fix pointer to the cursor exptected position
fix_locate_cursor_position:
	movem d0-d1,-(sp)

	move.b CursorX(a3),d0
	move.b CursorY(a3),d1
	jsr fix_layer_locate

	movem (sp)+,d0-d1

	rts

BasicNeo_cursor_blink_start:
	; Backup the character behind the cursor
	move.w REG_VRAMRW,CursorBlink_backup(a3)
	move.b #0,CursorBlink_counter(a3)
	rts

BasicNeo_cursor_blink_loop:
	move d0,-(sp)

	move.b CursorBlink_counter(a3),d0
	cmp #10,d0
	blt .b1
	cmp #20,d0
	blt .b2
	move.b #0,CursorBlink_counter(a3)
	bra .end
.b1:
	move #$f000,d0
	bra .show
.b2:
	move #$f000+' ',d0
.show:

	move.w #0,REG_VRAMMOD
	nop
	nop
	move.w d0,REG_VRAMRW
	nop
	nop
	move.w #$20,REG_VRAMMOD

.end:

	move (sp)+,d0
	rts

BasicNeo_cursor_blink_stop:
	move d0,-(sp)
	
	move.w #0,REG_VRAMMOD
	nop
	nop
	move.w CursorBlink_backup(a3),REG_VRAMRW
	nop
	nop
	move.w #$20,REG_VRAMMOD
	
	move (sp)+,d0
	rts