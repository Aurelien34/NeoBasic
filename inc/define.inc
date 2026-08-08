SYSTEM_ROM	equ $C00000
SYSTEM_ROM_MIRROR	equ $C20000
RAM_RESERVED_SYS_ROM	equ $10F300

RAM_START	equ $100000
RAM_USER_END	equ $10F300;
RAM_END	equ $110000

BACKUP_RAM_START equ $d00000
BACKUP_RAM_END equ $d10000

PALETTE_RAM_START equ $400000
PALETTE_RAM_END equ $402000
PALETTE_BACKDROP equ $401FFE

REG_PALBANK0 equ $3A001F
REG_PALBANK1 equ $3A000F

REG_CRTFIX equ $3A001B

REG_TIMERHIGH equ $3C0008
REG_TIMERLOW  equ $3C000A

REG_P1CNT equ $300000
BIT_BUTTON_UP equ 0
BIT_BUTTON_DOWN equ 1
BIT_BUTTON_LEFT equ 2
BIT_BUTTON_RIGHT equ 3
BIT_BUTTON_A equ 4
BIT_BUTTON_B equ 5
BIT_BUTTON_C equ 6
BIT_BUTTON_D equ 7

ROM_NAME_SECTION_ORG	equ $100
INITIAL_PC_ORG          equ $402

REG_WATCHDOG	equ $300001
REG_LSPCMODE	equ $3C0006
REG_IRQACK		equ $3C000C

; VRAM memory mapped registers
REG_VRAMADD	equ $3C0000
REG_VRAMRW	equ $3C0002
REG_VRAMMOD	equ $3C0004

; SOUND register
REG_SOUND equ $320000

; Inputs memory mapped registers
REG_P1CNT_REG_DIPSW equ $300000
REG_SYSTYPE equ $300080
REG_SOUND_REG_STATUS_A equ $320000
REG_P2CNT equ $340000
REG_STATUS_B equ $380000

VRAM_ADDRESS_FIX equ $7000

BRICO_PORT_OUT	equ SYSTEM_ROM+$1FF02
BRICO_PORT_EOT	equ BRICO_PORT_OUT-2
BRICO_KEYBOARD_IN equ SYSTEM_ROM+$1FFFA

    macro brico_command_header_one_letter
		move.w #\1,d0
		jsr port_write_d0
    endm

    macro brico_command_header
        brico_command_header_one_letter \1
        brico_command_header_one_letter \2
        brico_command_header_one_letter \3
        brico_command_header_one_letter \4
        brico_command_header_one_letter \5
    endm

    macro brico_command_header_print_text
        brico_command_header 'P','R','T','X','T'
    endm

    macro brico_command_header_print_hex
        brico_command_header 'P','R','H','E','X'
    endm

    macro brico_command_header_switch_bank
        brico_command_header 'S','W','B','N','K'
    endm

    macro brico_send_eot
        exg d0,a0
        move.w (SYSTEM_ROM+$1FF00).l,d0 ; EOT
		move.w #800,d0
	.\@wait:
		move.b	d0,(REG_WATCHDOG).l
		dbra d0,.\@wait
        exg d0,a0
    endm

    macro brico_send_word_d0
		and.l #$0000ffff,d0				; cleanup high word
		lsl.l d0						; times 2 (16 bits ROM)
		add.l #$C20000,d0				; locate in ROM mirror range to trigger the /OE line (under 0x0100, OE will not be triggered on non mirror location)
		move.l d0,a0					; Switch value to address register, as data is read on the address bus!
		DisableInterrupts
		move.w (BRICO_PORT_OUT).l,d0	; trigger port write
		move.w (a0),d0					; write value
	 	EnableInterrupts
    endm

BRICO_EXT_OUTPUT_TYPE_VOID equ $0
BRICO_EXT_OUTPUT_TYPE_WORD equ $1
BRICO_EXT_OUTPUT_TYPE_STRING equ $2
BRICO_EXT_OUTPUT_TYPE_DUMP equ $3

; BricoNeo special flags
BRICO_SPECIAL_FLAG_ENABLE_EXTENSIONS equ $0001		; Command extensions are active
BRICO_SPECIAL_FLAG_68K_SENDS_COMMANDS equ $0002		; The 68k can send commands using the output port
BRICO_SPECIAL_FLAG_68K_CEODIAG_CRC_MIRROR_COMPUTATION equ $0004	; Computes a valid NeoDiag CRC and trigger automatic mirroring of the ROM
BRICO_SPECIAL_FLAG_68K_REMOTE_KEYBOARD_MODE equ $0008 ; The 68k can send commands using the output port


	macro BRICONEO_VERSION
		dc.w \1	; Major
		dc.w \2	; Minor
	endm

	macro WatchDog
		move.b	d0,(REG_WATCHDOG).l
	endm

	macro EnableInterrupts
		move #$2000,sr				; Supervisor mode + all interrupts enabled
	endm

	macro DisableInterrupts
		move #$2700,sr				; Supervisor mode + all interrupts disabled
	endm

	macro Nop2
		nop
		nop
	endm

	macro Nop4
		Nop2
		Nop2
	endm

	macro Nop6
		Nop2
		Nop4
	endm

	macro Nop8
		Nop4
		Nop4
	endm

	macro Nop12
		Nop8
		Nop4
	endm

	macro Nop16
		Nop8
		Nop8
	endm


NEOBASIC_FIX_TOP_ROW EQU 2
NEOBASIC_FIX_LEFT_COLUMN EQU 1
NEOBASIC_FIX_HEIGHT EQU 28
NEOBASIC_FIX_WIDTH EQU 37
NEOBASIC_INITIAL_POSITION_X EQU 0
NEOBASIC_INITIAL_POSITION_Y EQU 0
NEOBASIC_KEYBOARD_QUEUE_SIZE EQU 128