// This module implements a testbench for the LED output module.
// It connects a RAM bank to the LED module, and then verifies that
// the LED module drives the expected data.

// Defines timescale for simulation: <time_unit / time_precision>
`timescale 1 ns / 10 ps

module led_output_tb();
	localparam MATRIX_HEIGHT = 4;
	localparam MATRIX_WIDTH = 8;
	localparam BANK_SIZE = (MATRIX_HEIGHT * MATRIX_WIDTH) / 2;

	localparam CLOCK_PERIOD = 83.34;

	// Storage elements
	reg clk = 0;
	reg rst = 0;
	reg go = 0;
	reg bank0_wen = 0;
	reg bank1_wen = 0;
	reg [15:0] w_data;
	reg [$clog2(BANK_SIZE) - 1:0] w_addr;
	integer i;

	// Outputs from LED module
	wire [1:0] r_out;
	wire [1:0] g_out;
	wire [1:0] b_out;
	wire latch;
	wire blank;
	wire led_clk;
	wire [4:0] led_addr;

	// Glue logic from memory to LED output
	wire [$clog2(BANK_SIZE) - 1:0] bank_raddr;
	wire [15:0] bank_data[0:1];


	// Dual memory banks for input to LED module, since scanlines
	// are interleaved
	memory#(.RAM_SIZE(BANK_SIZE))
	bank0(
		// Inputs
		.clk(clk),
		.r_en(1'b1),
		.w_en(bank0_wen),
		.w_data(w_data),
		.w_addr(w_addr),
		// Outputs
		.r_addr(bank_raddr),
		.r_data(bank_data[0])
	);

	memory#(.RAM_SIZE(BANK_SIZE))
	bank1(
		// Inputs
		.clk(clk),
		.r_en(1'b1),
		.w_en(bank1_wen),
		.w_data(w_data),
		.w_addr(w_addr),
		// Outputs
		.r_addr(bank_raddr),
		.r_data(bank_data[1])
	);

	// LED module under test
	led_output#(.MATRIX_HEIGHT(MATRIX_HEIGHT),
		    .MATRIX_WIDTH(MATRIX_WIDTH))
	uut(
		// Inputs
		.clk(clk),
		.rst(rst),
		.go(go),
		.rgb_0(bank_data[0]),
		.rgb_1(bank_data[1]),
		// Outputs
		.r_addr(bank_raddr),
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
		$dumpvars(0, led_output_tb);

		#CLOCK_PERIOD;
		// Reset the LED module
		rst = 1'b1;
		#CLOCK_PERIOD;
		rst = 1'b0;
		#CLOCK_PERIOD;

		bank0_wen = 1'b1;
		// Initialize bank0 memory using known data
		for (i = 0; i < BANK_SIZE; i = i + 1) begin
			w_addr = i;
			// RGB data block, where R, G, B are all set to "i"
			w_data = (i << 11) | (i << 5) | i;
			// Clock in the data
			#CLOCK_PERIOD;
		end

		bank0_wen = 1'b0;
		bank1_wen = 1'b1;
		// Initialize bank1 memory using known data
		for (i = 0; i < BANK_SIZE; i = i + 1) begin
			w_addr = i;
			// RGB data block, where R, G, B are all set to "i * 2"
			w_data = (i << 12) | (i << 6) | (i << 1);
			// Clock in the data
			#CLOCK_PERIOD;
		end
		bank1_wen = 1'b0;

		// Now, validate that the LED module has not started
		// clocking data
		if ((latch != 1'b0) || (led_clk != 1'b0) || (blank != 1'b1)) begin
			$error("LED module has clocked data before GO signal");
			$finish();
		end

		// Send go signal, and validate that LED clock goes high
		// One period to latch GO signal and 2 periods to fill pipeline
		go = 1'b1;
		#CLOCK_PERIOD
		go = 1'b0;
		#(2 * CLOCK_PERIOD);
		if (led_clk != 1'b0) begin
			$error("LED clock started too early");
			$finish();
		end
		// Delay one half period, make sure LED clock starts.
		// We will sample bits on this offset, since that is when
		// the LED driver would
		#(CLOCK_PERIOD/2);
		if (led_clk != 1'b1) begin
			$error("LED clock did not start");
			$finish();
		end
		// Check that R,G, and B outputs are present.
		// All should be clear, as address 0 has 0x0000
		if ((r_out != 2'b0) || (b_out != 2'b0) || (g_out != 2'b0)) begin
			$error("LED module clocked incorrect data");
			$finish();
		end
		// Clock the next set of bits out
		#CLOCK_PERIOD;
		// R/B should be clear, G should be 1, as address 1 has 0x821
		// and 0x1042
		if ((r_out != 2'b0) || (b_out != 2'b0) || (g_out != 2'b1)) begin
			$error("LED module clocked incorrect data");
			$finish();
		end
		// Clock next set of bits. We now expect all to be clear
		#CLOCK_PERIOD;
		if ((r_out != 2'b0) || (b_out != 2'b0) || (g_out != 2'b0)) begin
			$error("LED module clocked incorrect data");
			$finish();
		end
		// Next address has 0x1863 and 0x30C6. We expect G to be 1
		#CLOCK_PERIOD;
		if ((r_out != 2'b0) || (b_out != 2'b0) || (g_out != 2'b1)) begin
			$error("LED module clocked incorrect data");
			$finish();
		end
		// Send 5 additional clocks so we get to the end of the row
		// scan. Verify that we see latch high.
		#(5 * CLOCK_PERIOD);
		if ((latch != 1'b1) || (blank != 1'b1)) begin
			$error("LED module did not latch on row scan");
			$finish();
		end
		// Scan the remaining row (9 clocks total)
		// Verify that we see latch high, and that address is 1
		#(9 * CLOCK_PERIOD);
		if ((latch != 1'b1) || (blank != 1'b1) || (led_addr != 5'b1)) begin
			$error("LED module did not latch on row scan");
			$finish();
		end
		// Clock the first bit, and verify that we now see bit 2 being
		// scanned. All should be 0
		#CLOCK_PERIOD;
		if ((r_out != 2'b0) || (b_out != 2'b0) || (g_out != 2'b0)) begin
			$error("LED module clocked incorrect data");
			$finish();
		end
		// Delay to next clock. R and B should be 1, and G should be
		// 2.
		#CLOCK_PERIOD;
		if ((r_out != 2'b1) || (b_out != 2'b1) || (g_out != 2'b10)) begin
			$error("LED module clocked incorrect data");
			$finish();
		end
		// Scan the whole display, and return to address 0. We should
		// still see the same data being scanned.
		#(CLOCK_PERIOD * 16)
		if ((latch != 1'b1) || (blank != 1'b1) || (led_addr != 5'b1)) begin
			$error("LED module did not latch on row scan");
			$finish();
		end
		// Clock the first bit, and verify that we now see bit 2 being
		// scanned. All should be 0
		#CLOCK_PERIOD;
		if ((r_out != 2'b0) || (b_out != 2'b0) || (g_out != 2'b0)) begin
			$error("LED module clocked incorrect data");
			$finish();
		end
		// Delay to next clock. R and B should be 1, and G should be
		// 2.
		#CLOCK_PERIOD;
		if ((r_out != 2'b1) || (b_out != 2'b1) || (g_out != 2'b10)) begin
			$error("LED module clocked incorrect data");
			$finish();
		end

		$display("All tests passed");
		$finish();
	end
endmodule


