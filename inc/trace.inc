TRACE_PORT_OUT	    equ $0C1FF02
TRACE_PORT_EOT	    equ $0C1FF00
TRACE_PORT_CTR_IN	equ $0C1FFFE
TRACE_PORT_CMD_IN	equ $0C1FFFC

TRACE_CMD_STEP      equ 0
TRACE_CMD_CONTINUE  equ 1

	macro TraceOn
    	ori.w #$8000,sr ; Activate trace flag
        nop ; Trace starts after next instruction
	endm

	macro Breakpoint
    	TraceOn
	endm

	macro TraceOff
    	and.w #$7fff,sr ; Disable trace flag
	endm

    macro KickWatchdog
        move.b	d0,$300001
    endm