	include "inc/basic.inc"
	include "inc/define.inc"
	include "inc/trace.inc"

    global Extension_CLS, Extension_COLOR, Extension_LOCATE

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