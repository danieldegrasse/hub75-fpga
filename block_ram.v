// This module implements a block ram bank, which the will be used
// as graphics RAM when driving the LED array. Each data element is
// a 16 bit RGB565 value.

module memory #(
	// parameters
	parameter INIT_FILE = "",
	parameter RAM_SIZE = 0
)(
	// Inputs
	input clk,
	input [15:0] w_data,
	input [$clog2(RAM_SIZE) - 1:0] w_addr,
	input [$clog2(RAM_SIZE) - 1:0] r_addr,
	input w_en,
	input r_en,

	// Outputs
	output reg [15:0] r_data
);

	// Declare memory. Note we are using a 2D array
	reg [15:0] mem [0:RAM_SIZE - 1];

	// Interact with the memory block
	always @(posedge clk) begin
		// Write to memory
		if (w_en == 1'b1) begin
			mem[w_addr] <= w_data;
		end

		// Read from memory
		if (r_en == 1'b1) begin
			r_data <= mem[r_addr];
		end
	end

	// Initialize RAM if init file is available
	initial if (INIT_FILE) begin
		$readmemh(INIT_FILE, mem);
	end

endmodule
