OBJPATH = obj
OBJ = $(patsubst %.s,$(OBJPATH)/%.o,$(wildcard *.s))

ifeq ($(OS),Windows_NT)
	RM_CMD = cmd /C del /Q
else
	RM_CMD = rm -f
endif


run: Basic.bin
	copy Basic.bin E:

all: Basic.bin

rebuild:
	make clean
	make all

Basic.bin: $(OBJPATH) $(OBJ) Basic.ld
	./tools/vlink -b rawbin -T Basic.ld -o Basic.bin $(OBJ)

$(OBJPATH)/%.o: %.s inc/*.inc
	./tools/vasmm68k_mot -Fvobj -m68000 -quiet -nowarn=2028 -o $@ $<

$(OBJPATH):
	mkdir $(OBJPATH)

clean:
	$(RM_CMD) Basic.bin
	rmdir /S /Q obj
