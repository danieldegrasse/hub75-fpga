// This module implements the top glue logic for driving the matrix.

module top #(
	parameter CLOCK_DIV_FACTOR = 1
)(
	// Inputs
	input clk,
	input start,

	output wire [1:0] r,
	output wire [1:0] g,
	output wire [1:0] b,
	output wire [4:0] addr,
	output wire latch,
	output wire blank,
	output wire led_clk
);
	localparam MATRIX_HEIGHT = 32;
	localparam MATRIX_WIDTH = 64;
	localparam BANK_SIZE = (MATRIX_HEIGHT * MATRIX_WIDTH) / 2;

	// Glue logic from memory to LED output
	wire [$clog2(BANK_SIZE) - 1:0] bank_raddr;
	wire [15:0] bank_data[0:1];
	wire module_rst;
	reg rst;
	reg go;

	reg [$clog2(CLOCK_DIV_FACTOR):0] clk_count;
	reg div_clk;

	assign module_rst = ~start; // Active low signal

	always @(posedge clk or posedge module_rst) begin
		if (module_rst == 1'b1) begin
			// Reset clock div
			clk_count <= 'b0;
			div_clk <= 1'b0;
		end else if (clk_count == CLOCK_DIV_FACTOR) begin
			// Divider should yield 6 Hz clock
			clk_count <= 'b0;
			div_clk <= ~div_clk;
		end else begin
			clk_count <= clk_count + 1;
		end
	end

	// Glue logic to start LED module
	always @(posedge div_clk or posedge module_rst) begin
		if (module_rst == 1'b1) begin
			// Reset module.
			rst <= 1'b1;
			go <= 1'b0;
		end else if (rst == 1'b1) begin
			// Clear module reset
			rst <= 1'b0;
		end else if (go == 1'b0) begin
			// Set GO signal
			go <= 1'b1;
		end else begin
			// Clear GO signal
			go <= 1'b0;
		end
	end

	// Dual memory banks for input to LED module, since scanlines
	// are interleaved
	memory#(.RAM_SIZE(BANK_SIZE),
		.INIT_FILE("bank0_mem.txt"))
	bank0(
		// Inputs
		.clk(div_clk),
		.r_en(1'b1),
		.w_en(1'b0),
		.w_data(16'b0),
		.w_addr(10'b0),
		// Outputs
		.r_addr(bank_raddr),
		.r_data(bank_data[0])
	);

	memory#(.RAM_SIZE(BANK_SIZE),
		.INIT_FILE("bank1_mem.txt"))
	bank1(
		// Inputs
		.clk(div_clk),
		.r_en(1'b1),
		.w_en(1'b0),
		.w_data(16'b0),
		.w_addr(10'b0),
		// Outputs
		.r_addr(bank_raddr),
		.r_data(bank_data[1])
	);

	// LED module under test
	led_output#(.MATRIX_HEIGHT(MATRIX_HEIGHT),
		    .MATRIX_WIDTH(MATRIX_WIDTH))
	led_driver(
		// Inputs
		.clk(div_clk),
		.rst(rst),
		.go(go),
		.rgb_0(bank_data[0]),
		.rgb_1(bank_data[1]),
		// Outputs
		.r_addr(bank_raddr),
		.r(r),
		.g(g),
		.b(b),
		.latch(latch),
		.blank(blank),
		.led_clk(led_clk),
		.addr(addr)
	);
endmodule

