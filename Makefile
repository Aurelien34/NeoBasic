all: Basic68k3.0.bin

Basic68k3.0.bin: Basic68k3.0.x68
	./tools/vasmm68k_mot -Fbin -quiet -L Basic68k3.0.lst Basic68k3.0.x68 -o Basic68k3.0.bin