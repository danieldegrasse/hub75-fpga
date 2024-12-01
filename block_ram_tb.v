// Defines timescale for simulation: <time_unit / time_precision>
`timescale 1 ns / 10 ps

// Define memory testbench
module memory_tb();

	// Internal signals
	wire [15:0] r_data;

	// Storage elements
	reg clk = 0;
	reg w_en = 0;
	reg r_en = 0;
	reg[3:0] w_addr;
	reg[3:0] r_addr;
	reg[15:0] w_data;
	integer i;

	// Simulation time: 10000 * 10ns = 10us
	localparam DURATION = 10000;

	// Generate clock signal = ~12 MHz
	always begin
		#41.67
		clk = ~clk;
	end

	// Instantiate unit under test (UUT)
	memory #(.INIT_FILE("block_ram_mem.txt"),
		.RAM_SIZE(16))
	uut(
		.clk(clk),
		.w_data(w_data),
		.w_addr(w_addr),
		.r_data(r_data),
		.r_addr(r_addr),
		.w_en(w_en),
		.r_en(r_en)
	);

	// Run test: write to location and read value back
	initial begin

		// Test 1: read all data from memory
		for (i = 0; i < 16; i = i + 1) begin
			#(2 * 41.67) // Delay one clock cycle
			r_addr = i;
			r_en = 1;
			#(2 * 47.67) // Delay another clock cycle
			r_addr = 0;
			r_en = 0;
		end

		// Test 2: write 0xA5 to 0xF
		w_data = 'hA5;
		w_addr = 'hf;
		w_en = 1;
		#(2 * 47.67) // Delay another clock cycle
		// Clear write lines
		w_addr = 0;
		w_data = 0;
		w_en = 0;
		// Verify we now can read 0xA5 from ram
		r_addr = 'hf;
		r_en = 1;
		#(2 * 47.67) // Delay another clock cycle
		if (r_data != 'hA5) begin
			$error("Block ram read had incorrect value");
		end
		r_addr = 0;
		r_en =0;

	end

	// Initial block to run simulation
	initial begin
		$display("Writing simulation output to %s", `DUMP_FILE);
		// Create simulation output file
		$dumpfile(`DUMP_FILE);
		$dumpvars(0, memory_tb);

		// Wait for simulation to complete
		#(DURATION)

		// Notify and end simulation
		$display("Finished");
		$finish();
	end

endmodule

