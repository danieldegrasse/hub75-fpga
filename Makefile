# Makefile for simulation of the block ram component

# Hardware definitions. All synthesizable modules should
# be declared here, as some testbenches may use multiple modules.
HDL=block_ram.v led_output.v

# Testbenches should be named with the pattern <module_name>_tb.v,
# where <module_name> is the module to be tested. VCD dump files
# should be written to the value defined by the compiler as "DUMP_FILE",
# Like so:
# $dumpfile(`DUMP_FILE)
# simulations will be run from the root directory, and can load files
# as needed.

.PHONY: clean %.sim

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

clean:
	if [ -d build ]; then rm -r build; fi
	if [ -d sim ]; then rm -r sim; fi
