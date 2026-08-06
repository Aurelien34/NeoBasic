	include "inc/trace.inc"

    global TRACE
    global port_write_d0

	section	text

TRACE:
    ; trace; (SP) = SR(16 bits), (SP+2) = PC (32 bits)

    KickWatchdog

    ; Store state
    movem.l d0-d7/a0-a7,-(SP)

    ; send registers data
    move.w #31,d7
    move.w #0,d6
.registersLoop:
    move.w (sp,d6),d0
    bsr port_write_d0
    addi.w #2,d6
    dbra.w d7,.registersLoop

    ; send SR
    move.w (64,sp),d0
    bsr port_write_d0

    ; send PC
    move.w (66,sp),d0
    bsr port_write_d0
    move.w (68,sp),d0
    bsr port_write_d0

    ; send PC memory neighbourhood
    move.w (66,SP),d0
    swap d0
    move.w (68,SP),d0
    move.l d0,a0
    move.w #5*5-1,d7
.loopPcMemory
    move.w (a0)+,d0
    bsr port_write_d0
    dbra.w d7,.loopPcMemory

    ; send trace counter
    move.w TRACE_PORT_CTR_IN,d0
    bsr port_write_d0

    ; end of debug frame
    move.w (TRACE_PORT_EOT).l,d7

    ; wait for command
.loop:
    KickWatchdog
    move.w TRACE_PORT_CTR_IN,d1
    cmp.w d0,d1
    beq .loop

    move.w TRACE_PORT_CMD_IN,d0
    cmp.w #TRACE_CMD_STEP,d0
    beq .cmdStep
    cmp.w #TRACE_CMD_CONTINUE,d0
    beq .cmdContinue
    bra .cmdStep

.cmdContinue
    andi.w #$7fff,(64,sp) ; disable the trace flag in the stack frame
    bra .cmdStep

.cmdStep:
    ; default: jump to next step

    ; Restore state
    movem.l (SP)+,d0-d7/a0-a7

    rte

port_write_d0:
    movem.l d0-d1/a0,-(sp)
    move.w sr,d1

    and.l #$0000ffff,d0				; cleanup high word
    lsl.l d0						; times 2 (16 bits ROM)
    add.l #$C20000,d0		        ; locate in ROM mirror range to trigger the /OE line (under 0x0100, OE will not be triggered on non mirror location)
    exg d0,a0						; Switch value to address register, as data is read on the address bus!
	move #$2700,sr					; Supervisor mode + all interrupts disabled
    move.w (TRACE_PORT_OUT).l,d0	; trigger port write
    move.w (a0),d0					; write value

    move.w d1,sr
    movem.l (sp)+,d0-d1/a0
    rts
