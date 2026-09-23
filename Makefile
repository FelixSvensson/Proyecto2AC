# Proyecto 2 - Arquitectura de Computadores 2026-2

# --------------------------------------------------
# Configuration
# --------------------------------------------------

TOP := game_top
PCF := goboard.pcf

# Software
GAME_ASM := sw/game.s
GAME_HEX := sw/game.hex
ASSEMBLER := assembler/assembler.py

# RTL sources
SRC := $(wildcard ./rtl/*.v ./rtl/**/*.v)

# FPGA build files
JSON := $(TOP).json
ASC  := $(TOP).asc
BIN  := $(TOP).bin


.PHONY: all game test prog clean stats

# --------------------------------------------------
# Default
# --------------------------------------------------

all: $(BIN)


# --------------------------------------------------
# Software
# game.s -> game.hex using OUR assembler
# --------------------------------------------------

game: $(GAME_HEX)

$(GAME_HEX): $(GAME_ASM) $(ASSEMBLER)
	python3 $(ASSEMBLER) $(GAME_ASM) $(GAME_HEX)


# --------------------------------------------------
# FPGA synthesis
# --------------------------------------------------

$(JSON): $(SRC) $(GAME_HEX)
	yosys -p "read_verilog $(SRC); synth_ice40 -top $(TOP) -json $(JSON); stat"


# --------------------------------------------------
# Place and route
# --------------------------------------------------

$(ASC): $(JSON) $(PCF)
	nextpnr-ice40 --hx1k --package vq100 --json $(JSON) --pcf $(PCF) --asc $(ASC)


# --------------------------------------------------
# Bitstream
# --------------------------------------------------

$(BIN): $(ASC)
	icepack $(ASC) $(BIN)
# --------------------------------------------------
# Tests
# --------------------------------------------------

test:
	python3 assembler/test_assembler.py
	iverilog -g2012 -o /tmp/pochoco_periph_tb sim/pochoco_periph_tb.v rtl/pochoco_periph.v
	vvp /tmp/pochoco_periph_tb

# --------------------------------------------------
# Program FPGA
# --------------------------------------------------

prog: $(BIN)
	iceprog $(BIN)


# --------------------------------------------------
# Clean generated FPGA files
# --------------------------------------------------

clean:
	rm -f $(JSON) $(ASC) $(BIN)


# --------------------------------------------------
# Resource statistics
# --------------------------------------------------

stats: $(JSON)
	yosys -p "read_json $(JSON); stat"
