// This module implements a testbench for the top glue logic

// Defines timescale for simulation: <time_unit / time_precision>
`timescale 1 ns / 10 ps

module top_tb();
	localparam CLOCK_PERIOD = 83.34;

	// Storage elements
	reg clk = 0;
	reg start = 0;

	// Outputs from LED module
	wire [1:0] r_out;
	wire [1:0] g_out;
	wire [1:0] b_out;
	wire latch;
	wire blank;
	wire led_clk;
	wire [4:0] led_addr;

	// module under test
	top#(.CLOCK_DIV_FACTOR(1))
	uut(
		// Inputs
		.clk(clk),
		.start(start),
		// Outputs
		.r(r_out),
		.g(g_out),
		.b(b_out),
		.latch(latch),
		.blank(blank),
		.led_clk(led_clk),
		.addr(led_addr)
	);

	// Generate clock signal = ~12 MHz
	always begin
		#(CLOCK_PERIOD / 2);
		clk = ~clk;
	end

	initial begin
		$display("Writing simulation output to %s", `DUMP_FILE);
		// Create simulation output file
		$dumpfile(`DUMP_FILE);
		$dumpvars(0, top_tb);

		#CLOCK_PERIOD;
		// Start the LED module
		start = 1'b0;
		#CLOCK_PERIOD;
		start = 1'b1;
		#CLOCK_PERIOD;

		// Clock the LED module
		#(CLOCK_PERIOD * 65 * 10000)

		$finish();
	end
endmodule


