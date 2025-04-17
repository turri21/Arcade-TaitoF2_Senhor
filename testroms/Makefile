CC = m68k-elf-gcc
OBJCOPY = m68k-elf-objcopy
OBJDUMP = m68k-elf-objdump
MAME = ../util/taito_mame
PYTHON = uv --project ../util run
SPLIT_ROM = $(PYTHON) ../util/split_rom.py
MISTER_HOSTNAME=mister-dev

TARGET = finalb_test
SRCS = init.c main.c interrupts_default.c comms.c tilemap.c input.c printf/printf.c
SRCS += obj_test.c
CHR = font.chr 
ASM = 

BUILD_DIR = build/$(TARGET)
ROM_DIR = ../roms

OBJS = $(addprefix $(BUILD_DIR)/, $(SRCS:c=o)) $(addprefix $(BUILD_DIR)/, $(CHR:chr=o)) $(addprefix $(BUILD_DIR)/, $(ASM:s=o))
BUILD_DIRS = $(sort $(dir $(OBJS))) 
GLOBAL_DEPS = Makefile

DEFINES = -DPRINTF_SUPPORT_DECIMAL_SPECIFIERS=0 \
	-DPRINTF_SUPPORT_EXPONENTIAL_SPECIFIERS=0 \
	-DPRINTF_SUPPORT_LONG_LONG=0 \
	-DPRINTF_ALIAS_STANDARD_FUNCTION_NAMES=1 \
	-DPRINTF_ALIAS_STANDARD_FUNCTION_NAMES_HARD=1

CFLAGS = -march=68000 -ffreestanding $(DEFINES) -O2 --std=c2x -g
LIBS = -lgcc
LDFLAGS = -march=68000 -static -nostdlib -g


ifeq ($(TARGET),finalb_test)
GAME = finalb
CPU_ROM_LOW = b82-09.ic23
CPU_ROM_HIGH = b82-17.ic11
CPU_ROM_SIZE = 0x40000
else
error
endif

GAME_DIR = $(BUILD_DIR)/$(GAME)
BUILT_BINS = $(addprefix $(GAME_DIR)/, $(CPU_ROM_LOW) $(CPU_ROM_HIGH))

ROMPATH = ../$(BUILD_DIR);../$(ROM_DIR)

all: $(BUILT_BINS)

$(BUILD_DIR)/cpu.bin: $(BUILD_DIR)/cpu.elf
	$(OBJCOPY) -O binary $< $@

$(GAME_DIR)/$(CPU_ROM_HIGH): $(BUILD_DIR)/cpu.bin | $(GAME_DIR)
	$(SPLIT_ROM) $@ $< 2 1 $(CPU_ROM_SIZE)

$(GAME_DIR)/$(CPU_ROM_LOW): $(BUILD_DIR)/cpu.bin | $(GAME_DIR)
	$(SPLIT_ROM) $@ $< 2 0 $(CPU_ROM_SIZE)


$(BUILD_DIR)/%.o: %.c $(GLOBAL_DEPS) | $(BUILD_DIRS)
	@echo $@
	@$(CC) -MMD -o $@ $(CFLAGS) -c $<

$(BUILD_DIR)/%.o: %.s $(GLOBAL_DEPS) | $(BUILD_DIRS)
	@echo $@
	@$(CC) -MMD -o $@ $(CFLAGS) -c $<

$(BUILD_DIR)/%.o: %.chr $(GLOBAL_DEPS) | $(BUILD_DIRS)
	$(OBJCOPY) -I binary -O default $< $@

$(BUILD_DIR)/cpu.elf: $(OBJS)
	@echo $@
	@$(CC) -T f2.ld -o $@ $(LDFLAGS) $^ $(LIBS)
	@$(OBJDUMP) -d -S $@ > $(BUILD_DIR)/cpu.asm

$(BUILD_DIRS):
	mkdir -p $@

$(GAME_DIR):
	mkdir -p $@



debug: $(BUILT_BINS)
	mkdir -p mame
	cd mame && ../$(MAME) -window -nomaximize -resolution0 640x480 -debug -debugscript ../debugscript.txt -rompath "$(ROMPATH)" $(GAME)

run: $(BUILT_BINS)
	mkdir -p mame
	cd mame && ../$(MAME) -window -nomaximize -resolution0 640x480 -rompath "$(ROMPATH)" $(GAME)

picorom: $(GAME_DIR)/$(CPU_ROM_HIGH) $(GAME_DIR)/$(CPU_ROM_LOW)
	picorom reset cpu_low low
	picorom upload cpu_low $(GAME_DIR)/$(CPU_ROM_LOW)
	picorom upload cpu_high $(GAME_DIR)/$(CPU_ROM_HIGH)
	picorom reset cpu_low z

.PHONY: run debug picorom

-include $(OBJS:o=d)
