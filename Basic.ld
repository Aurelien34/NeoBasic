MEMORY {
	VECTORS: org=0xc00000, len=0x00080
	HEADER:  org=0xc00080, len=0x00f80
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
