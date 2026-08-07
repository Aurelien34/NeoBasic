	include "inc/basic.inc"
	include "inc/define.inc"
	include "inc/trace.inc"

    global Extension_CLS, Extension_COLOR, Extension_LOCATE, Extension_STICK, Extension_STRIG, Extension_SSTART

	section	text

Extension_CLS:
    jsr fix_layer_cls
    move.b #0,CursorX(a3)
    move.b #0,CursorY(a3)
	jsr fix_locate_cursor_position
    rts

; Color index (0-15) in d0
Extension_COLOR:
    lsl.w #4,d0
    lsl.w #8,d0
    move.w d0,CurrentColorMask(a3)
    rts

; X in d0, Y in d1
Extension_LOCATE:
    move.b d0,CursorX(a3)
    move.b d1,CursorY(a3)
    JSR fix_locate_cursor_position
    rts

; n in d0, returns position in d0
Extension_STICK
    cmp.b #0,d0
    bne .player2
    move.b REG_P1CNT_REG_DIPSW,d0
    bra .read
.player2
    move.b REG_P2CNT,d0
.read
    not.b d0
    andi.b #$0f,d0
    rts

; n in d0, returns position in d0
Extension_STRIG
    cmp.b #0,d0
    bne .player2
    move.b REG_P1CNT_REG_DIPSW,d0
    bra .read
.player2
    move.b REG_P2CNT,d0
.read
    not.b d0
    lsr.b #4,d0
    rts

; n in d0, returns START button state in d0
Extension_SSTART
    move.b REG_STATUS_B,d1
    NOT.b d1
    cmp.b #0,d0
    bne .player2
    btst #0,d1
    bra .read
.player2
    btst #2,d1
.read
    beq .not_pressed
    move.b #1,d0
    rts
.not_pressed
    move.b #0,d0
    rts