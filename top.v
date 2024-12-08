// This module implements the top glue logic for driving the matrix.

module top(
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

	// For now, we will simply drive the matrix using some hardcoded
	// values. This way, we can be sure the design actually works on
	// hardware.

	assign r[0] = 1'b1;
	assign r[1] = 1'b0;

	assign g[0] = 1'b0;
	assign g[1] = 1'b0;

	assign b[0] = 1'b0;
	assign b[1] = 1'b1;

	localparam STATE_CLOCKING = 0;
	localparam STATE_LATCHING = 1;
	localparam MATRIX_WIDTH = 64;
	localparam MATRIX_HEIGHT = 32;

	reg state;
	reg [$clog2(MATRIX_WIDTH) - 1: 0] led_clk_count;
	reg [4:0] led_addr;

	assign addr = led_addr;

	assign led_clk = (clk & (state == STATE_CLOCKING));
	assign latch = (state == STATE_LATCHING);
	// Blank is active low signal
	assign blank = ~(state == STATE_CLOCKING);

	always @(posedge clk) begin
		if (start == 1'b0) begin
			// Start signal is active low. Move into clocking state.
			state <= STATE_CLOCKING;
			led_clk_count <= 'b0;
			led_addr <= 5'b0;
		end else begin
			case (state)
				STATE_CLOCKING: begin
					if (led_clk_count == (MATRIX_WIDTH - 1)) begin
						// Move to latching state
						state <= STATE_LATCHING;
						led_clk_count <= 'b0;
					end else begin
						led_clk_count <= led_clk_count + 1;
					end
				end
				STATE_LATCHING: begin
					if (led_addr == ((MATRIX_HEIGHT / 2) - 1)) begin
						// Move back to address 0
						led_addr <= 5'b0;
					end else begin
						// Move address forwards
						led_addr <= led_addr + 1;
					end
					state <= STATE_CLOCKING;
				end
			endcase
		end
	end
endmodule

