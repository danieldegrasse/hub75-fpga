// This module implements an engine for outputting RGB565
// color data in the format expected by the LED panel.
//
// The panel is driven with interleaved scanlines. Five address lines are
// used to select the two active output lines (scanlines are interleaved).
// Then, data is clocked out on 6 pins (3 per output line) to set each LED.
// For a 64x64 matrix, there would be 32 possible addresses, and 64 clocks
// of data would be sent each time.
//
// Good resource on how to drive this matrix:
// https://justanotherelectronicsblog.com/?p=636

// We want to convert from RGB565 to this display format- rather than
// discarding data, we will drive the LEDs fast enough to "fake" the same
// effect as if the RGB565 data were being displayed.
// To simulate intensity properly, we need to drive the LEDs twice as long
// for each successive bit. IE R[0], G[0], and B[0] would be driven for
// one timeslice, and R[1], G[1], and B[1] would be driven for two timeslices.
// Internally, we will normalize the red and blue channel to also be 6 bits
// that we can avoid any weirdness around how to drive them.


module led_output #(
	// parameters
	parameter MATRIX_HEIGHT = 0,
	parameter MATRIX_WIDTH = 0
)(
	// Inputs
	input clk,
	input rst,
	input go, // Starts scanning
	input [15:0] rgb_0, // Row one of interleave
	input [15:0] rgb_1, // Row two of interleave

	// Outputs
	output reg [$clog2(MATRIX_HEIGHT * MATRIX_WIDTH / 2) - 1:0] r_addr,
	output wire [1:0] r,
	output wire [1:0] g,
	output wire [1:0] b,
	output reg [4:0] addr,
	output wire latch,
	output wire blank,
	output wire led_clk
);
	localparam LED_COUNT_WIDTH = $clog2(MATRIX_WIDTH) - 1;
	// FSM state definitions
	localparam IDLE_STATE = 2'd0; // Module is idle
	localparam QUEUE_STATE = 2'd1; // Filling module pipeline
	localparam CLOCKING_STATE = 2'd2; // Clocking LED data to drivers
	localparam LATCHING_STATE = 2'd3; // Latching LED data

	// R and B raw data. Note the width is chosen based on the
	// max value possible while the data is being normalized.
	wire [10:0] r_raw [0:1];
	wire [10:0] b_raw [0:1];

	// Normalized R, G, and B data
	wire [5:0] r_norm [0:1];
	wire [5:0] g_norm [0:1];
	wire [5:0] b_norm [0:1];

	// Pipelined R, G, and B bits
	reg [1:0] r_stage1;
	reg [1:0] r_stage2;
	reg [1:0] g_stage1;
	reg [1:0] g_stage2;
	reg [1:0] b_stage1;
	reg [1:0] b_stage2;

	assign r = r_stage2;
	assign g = g_stage2;
	assign b = b_stage2;

	// tracks FSM state
	reg [2:0] state;
	// Tracks clock counts for this line
	reg [LED_COUNT_WIDTH:0] led_clk_count;
	// Tracks delay cycle count for the bit we are sending.
	reg [5:0] bit_delay;
	// Tracks raw RGB bit we are sending
	reg [2:0] bit_idx;

	// R and B raw data. Note the width is chosen based on the
	// max value possible while the data is being normalized.
	assign r_raw [0] = rgb_0[15:11] * 63;
	assign r_raw [1] = rgb_1[15:11] * 63;
	assign b_raw [0] = rgb_0[4:0] * 63;
	assign b_raw [1] = rgb_1[4:0] * 63;

	// Normalized R, G, and B data
	assign r_norm [0] = r_raw[0] / 31;
	assign r_norm [1] = r_raw[1] / 31;
	assign g_norm [0] = rgb_0[10:5];
	assign g_norm [1] = rgb_1[10:5];
	assign b_norm [0] = b_raw[0] / 31;
	assign b_norm [1] = b_raw[1] / 31;

	// Reusable task to shift the RGB data in pipeline
	task pipeline_fill;
		begin
			// Fill pipeline stage 1 from RGB data in memory
			r_stage1[0] <= r_norm[0][bit_idx];
			r_stage1[1] <= r_norm[1][bit_idx];
			g_stage1[0] <= g_norm[0][bit_idx];
			g_stage1[1] <= g_norm[1][bit_idx];
			b_stage1[0] <= b_norm[0][bit_idx];
			b_stage1[1] <= b_norm[1][bit_idx];
			// Shift stage1 of pipeline to stage2
			r_stage2[0] <= r_stage1[0];
			r_stage2[1] <= r_stage1[1];
			g_stage2[0] <= g_stage1[0];
			g_stage2[1] <= g_stage1[1];
			b_stage2[0] <= b_stage1[0];
			b_stage2[1] <= b_stage1[1];
			// Move read address
			r_addr <= r_addr + 1;
		end
	endtask


	//
	// We implement the core logic of this module as an FSM, with the
	// following states:
	// - idle: module is waiting for start signal
	// - clocking: clocking a row of LED data
	// - latching: latching the LED data into the driver
	//
	// Note that we pipeline reads from the ram bank, so that we don't
	// have to wait an additional clock cycle for RGB data

	// LED clock should follow the input clock when state is clocking
	assign led_clk = ((~clk) & (state == CLOCKING_STATE));
	// Latch should go high when we enter latching state
	assign latch = (state == LATCHING_STATE);
	// Blank should be high when we aren't clocking data
	assign blank = (state != CLOCKING_STATE);

	always @(posedge clk) begin
		if (rst == 1'b1) begin
			state <= IDLE_STATE;
			// Reset module outputs
			r_stage1 <= 2'b0;
			g_stage1 <= 2'b0;
			b_stage1 <= 2'b0;
			r_stage2 <= 2'b0;
			g_stage2 <= 2'b0;
			b_stage2 <= 2'b0;
			r_addr <= 'b0;
			addr <= 2'b0;
			led_clk_count <= 'b0;
			bit_idx <= 3'b0;
			bit_delay <= 5'b0;
		end else begin
			case (state)
				// Wait for the go signal
				IDLE_STATE: begin
					if (go == 1'b1) begin
						// Move to the QUEUE state
						state <= QUEUE_STATE;
						// start filling pipeline
						pipeline_fill();
					end
				end

				QUEUE_STATE: begin
					pipeline_fill();
					if (r_addr == 'd2) begin
						// Pipeline is full
						state <= CLOCKING_STATE;
					end
				end

				// Clock LEDs
				CLOCKING_STATE: begin
					// Move data from pipeline
					pipeline_fill();
					led_clk_count <= led_clk_count + 1;
					if (led_clk_count == MATRIX_WIDTH - 1) begin
						// Move to latching state
						state <= LATCHING_STATE;
					end
					if (r_addr == ((MATRIX_HEIGHT * MATRIX_WIDTH) / 2 - 1)) begin
						// Scanned entire frame. Move
						// bit index.
						bit_delay <= bit_delay - 1;
						if (bit_delay == 0) begin
							bit_idx <= bit_idx + 1;
							if (bit_idx == 3'd5) begin
								// Reset index and delay
								bit_idx <= 5'b0;
								bit_delay <= 5'b0;
							end else begin
								bit_delay <= (2 ** (bit_idx + 1)) - 1;
							end
						end
					end
				end

				LATCHING_STATE: begin
					// Reset clock count
					led_clk_count <= 'b0;
					// Move to clocking state
					state <= CLOCKING_STATE;
					if (addr == ((MATRIX_HEIGHT / 2) - 1)) begin
						// End of column scan, reset address
						addr <= 5'b0;
					end else begin
						// End of row scan. Move address.
						addr <= addr + 1;
					end
				end

				default: begin
					// Move to idle state
					state <= IDLE_STATE;
				end
			endcase
		end
	end
endmodule
