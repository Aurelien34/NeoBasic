all: Basic.bin

Basic.bin: Basic.o Basic.ld
	./tools/vlink -b rawbin -T Basic.ld -o Basic.bin Basic.o

Basic.o: Basic.s
	./tools/vasmm68k_mot -Fvobj -quiet -L Basic.lst Basic.s -o Basic.o

clean:
	rm -f Basic.bin Basic.lst Basic.o