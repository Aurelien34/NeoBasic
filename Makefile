all: Basic.bin

Basic.bin: Basic.s
	./tools/vasmm68k_mot -Fbin -quiet -L Basic.lst Basic.s -o Basic68k3.0.bin