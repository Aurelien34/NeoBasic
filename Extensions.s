	include "inc/basic.inc"
	include "inc/define.inc"
	include "inc/trace.inc"

    global Extension_CLS

	section	text

Extension_CLS:
    jsr fix_layer_cls
    move.b #0,CursorX(a3)
    move.b #0,CursorY(a3)
	bsr fix_locate_cursor_position
    rts