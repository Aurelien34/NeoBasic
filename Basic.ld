MEMORY {
	VECTORS: org=0xc00000, len=0x00400
	HEADER:  org=0xc00400, len=0x00c00
	ROM:     org=0xc01000, len=0x10000
}

SECTIONS {
	.vectors: {
		*(vectors)
	} >VECTORS

	.header: {
		*(header)
	} >HEADER

	.rom: {
		*(text)
	} >ROM
}
