OBJPATH = obj
LABPATH=.\TestPrograms\Source
BASPATH=.\TestPrograms\Basic

OBJ = $(patsubst %.s,$(OBJPATH)/%.o,$(wildcard *.s))
LAB_SRC = $(wildcard $(LABPATH)/*.lab)
BAS_OUT = $(patsubst $(LABPATH)/%.lab,$(BASPATH)/%.bas,$(LAB_SRC))

FS_MANIFEST = Programs.txt
FS_GEN = $(OBJPATH)/FileSystem.gen.s
FS_OBJ = $(OBJPATH)/FileSystem.gen.o

ifeq ($(OS),Windows_NT)
	RM_CMD = cmd /C del /Q
else
	RM_CMD = rm -f
endif

rom: Basic.bin

run: Basic.bin
	copy Basic.bin E:

bas: $(BASPATH) $(BAS_OUT)

$(BASPATH)/%.bas: $(LABPATH)/%.lab
	powershell -NoProfile -ExecutionPolicy Bypass -File LabToBas.ps1 $< $@

$(BASPATH):
	mkdir $(BASPATH)

rebuild:
	make clean
	make all

Basic.bin: $(OBJPATH) $(OBJ) $(FS_OBJ) Basic.ld
	./tools/vlink -b rawbin -T Basic.ld -o Basic.bin $(OBJ) $(FS_OBJ)

$(FS_GEN): $(OBJPATH) $(BASPATH) $(FS_MANIFEST) MakeFileSystem.ps1 $(BAS_OUT)
	powershell -NoProfile -ExecutionPolicy Bypass -File MakeFileSystem.ps1 -Manifest $(FS_MANIFEST) -Output $(FS_GEN)

$(FS_OBJ): $(FS_GEN)
	./tools/vasmm68k_mot -Fvobj -m68000 -quiet -nowarn=2028 -o $@ $<

$(OBJPATH)/%.o: %.s inc/*.inc
	./tools/vasmm68k_mot -Fvobj -m68000 -quiet -nowarn=2028 -o $@ $<

$(OBJPATH):
	mkdir $(OBJPATH)

clean:
	$(RM_CMD) Basic.bin
	rmdir /S /Q obj
