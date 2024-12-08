# Makefile for simulation of the block ram component

# Hardware definitions. All synthesizable modules should
# be declared here, as some testbenches may use multiple modules.
HDL=block_ram.v led_output.v top.v
# Constraint files
PCF=top.pcf

# Testbenches should be named with the pattern <module_name>_tb.v,
# where <module_name> is the module to be tested. VCD dump files
# should be written to the value defined by the compiler as "DUMP_FILE",
# Like so:
# $dumpfile(`DUMP_FILE)
# simulations will be run from the root directory, and can load files
# as needed.

.PHONY: program upload build clean %.sim

# Dummy target, we need to provide a command to actually
# run synthesis or simulation
all:
	@echo "Please provide a command"

%.sim: sim/%_tb.sim
	# Run simulation, open output in gtkwave
	$<
	open $(basename $<).vcd

sim/%_tb.sim: %_tb.v $(HDL)
	# Make simulation directory
	if [ ! -d sim ]; then mkdir sim; fi
	# Build with iverilog
	iverilog -o $@ -DDUMP_FILE=\"$(basename $@).vcd\" $(HDL) $<

program: build/hardware.bin
	# Upload using DFU slot alt 0 (SPI), so the image is permanent
	dfu-util -D build/hardware.bin -a 0

upload: build/hardware.bin
	# Upload using DFU slot alt 1 (CRAM), so the image is temporary
	dfu-util -D build/hardware.bin -a 1

build: build/hardware.bin

build/hardware.bin: $(HDL) $(PCF)
	# Make build directory
	if [ ! -d build ]; then mkdir build; fi
	# Run yosys with synthesis command for ice40, output to build/hardware.json
	yosys -p "synth_ice40 -json build/hardware.json" -q $(HDL)
	# Route using nextpnr, targeting ICE40UP5K, SG48 package
	# Write to hardware.asc file
	nextpnr-ice40 --up5k --package sg48 --json build/hardware.json \
		--asc build/hardware.asc --pcf $(PCF) -q
	icepack build/hardware.asc build/hardware.bin

clean:
	if [ -d build ]; then rm -r build; fi
	if [ -d sim ]; then rm -r sim; fi
