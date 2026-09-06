MEMORY {
	VECTORS: org=0xc00000, len=0x00080
	HEADER:  org=0xc00080, len=0x00020
	TRAP15:  org=0xc000bc, len=0x00004
	ROM:     org=0xc000c0, len=0x1fe00
}

SECTIONS {
	.vectors: {
		*(vectors)
	} >VECTORS

	.header: {
		*(header)
	} >HEADER

	.trap15: {
		*(trap15)
	} >TRAP15

	.rom: {
		*(text)
	} >ROM
}
