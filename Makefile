ifeq ($(OS),Windows_NT)
	RM_CMD = cmd /C del /Q
else
	RM_CMD = rm -f
endif

all: Basic.bin

rebuild:
	make clean
	make all

Basic.bin: Basic.o Basic.ld
	./tools/vlink -b rawbin -T Basic.ld -o Basic.bin Basic.o

Basic.o: Basic.s
	./tools/vasmm68k_mot -Fvobj -quiet -L Basic.lst -nowarn=2028 Basic.s -o Basic.o

clean:
	$(RM_CMD) Basic.bin Basic.lst Basic.o