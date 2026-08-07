OBJPATH = obj
LABPATH=.\TestPrograms\Source
BASPATH=.\TestPrograms\Basic

OBJ = $(patsubst %.s,$(OBJPATH)/%.o,$(wildcard *.s))
LAB_SRC = $(wildcard $(LABPATH)/*.lab)
BAS_OUT = $(patsubst $(LABPATH)/%.lab,$(BASPATH)/%.bas,$(LAB_SRC))

ifeq ($(OS),Windows_NT)
	RM_CMD = cmd /C del /Q
else
	RM_CMD = rm -f
endif


run: Basic.bin
	copy Basic.bin E:

rom: Basic.bin

bas: $(BASPATH) $(BAS_OUT)

$(BASPATH)/%.bas: $(LABPATH)/%.lab
	powershell -NoProfile -ExecutionPolicy Bypass -File LabToBas.ps1 $< $@

$(BASPATH):
	mkdir $(BASPATH)

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
