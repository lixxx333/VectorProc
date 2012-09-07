// 
// Copyright 2011-2012 Jeff Bush
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// 

//
// Top level module for simulator
//

module simulator_top;
	
	parameter NUM_STRANDS = 4;
	parameter NUM_REGS = 32;

	reg 			clk;
	integer 		i;
	reg[1000:0] 	filename;
	reg[31:0] 		regtemp[0:17 * NUM_REGS * NUM_STRANDS - 1];
	integer 		do_register_dump;
	integer			do_register_trace;
	integer 		do_state_trace;
	integer			state_trace_fp;
	integer 		mem_dump_start;
	integer 		mem_dump_length;
	reg[31:0] 		mem_dat;
	integer 		simulation_cycles;
	wire			processor_halt;
	integer			fp;
	reg[31:0] 		wb_pc = 0;
	integer			dummy_return;
	integer			do_autoflush_l2;
	
	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire [31:0]	axi_araddr;		// From l2_cache of l2_cache.v
	wire [7:0]	axi_arlen;		// From l2_cache of l2_cache.v
	wire		axi_arready;		// From memory of sim_memory.v
	wire		axi_arvalid;		// From l2_cache of l2_cache.v
	wire [31:0]	axi_awaddr;		// From l2_cache of l2_cache.v
	wire [7:0]	axi_awlen;		// From l2_cache of l2_cache.v
	wire		axi_awready;		// From memory of sim_memory.v
	wire		axi_awvalid;		// From l2_cache of l2_cache.v
	wire		axi_bready;		// From l2_cache of l2_cache.v
	wire		axi_bvalid;		// From memory of sim_memory.v
	wire [31:0]	axi_rdata;		// From memory of sim_memory.v
	wire		axi_rready;		// From l2_cache of l2_cache.v
	wire		axi_rvalid;		// From memory of sim_memory.v
	wire [31:0]	axi_wdata;		// From l2_cache of l2_cache.v
	wire		axi_wlast;		// From l2_cache of l2_cache.v
	wire		axi_wready;		// From memory of sim_memory.v
	wire		axi_wvalid;		// From l2_cache of l2_cache.v
	wire [1:0]	l2rsp_core;		// From l2_cache of l2_cache.v
	wire [511:0]	l2rsp_data;		// From l2_cache of l2_cache.v
	wire [1:0]	l2rsp_op;		// From l2_cache of l2_cache.v
	wire		l2rsp_status;		// From l2_cache of l2_cache.v
	wire [1:0]	l2rsp_strand;		// From l2_cache of l2_cache.v
	wire [1:0]	l2rsp_unit;		// From l2_cache of l2_cache.v
	wire		l2rsp_update;		// From l2_cache of l2_cache.v
	wire		l2rsp_valid;		// From l2_cache of l2_cache.v
	wire [1:0]	l2rsp_way;		// From l2_cache of l2_cache.v
	// End of automatics
	
	wire l2req_valid;
	wire l2req_ack;
	wire[1:0] l2req_core;
	wire[1:0] l2req_unit;
	wire[1:0] l2req_strand;
	wire[2:0] l2req_op;
	wire[1:0] l2req_way;
	wire[25:0] l2req_address;
	wire[511:0] l2req_data;
	wire[63:0] l2req_mask;
	wire l2req_valid_core0;
	wire l2req_ack_core0;
	wire[1:0] l2req_core_core0;
	wire[1:0] l2req_unit_core0;
	wire[1:0] l2req_strand_core0;
	wire[2:0] l2req_op_core0;
	wire[1:0] l2req_way_core0;
	wire[25:0] l2req_address_core0;
	wire[511:0] l2req_data_core0;
	wire[63:0] l2req_mask_core0;
	wire l2req_valid_core1;
	wire[1:0] l2req_core_core1;
	wire[1:0] l2req_unit_core1;
	wire[1:0] l2req_strand_core1;
	wire[2:0] l2req_op_core1;
	wire[1:0] l2req_way_core1;
	wire[25:0] l2req_address_core1;
	wire[511:0] l2req_data_core1;
	wire[63:0] l2req_mask_core1;
	wire l2grant_core0;
	wire l2grant_core1;

	wire processor_halt0;
	wire processor_halt1;
	assign processor_halt = processor_halt0 | processor_halt1;	
	
	arbiter #(2) l2req_arb(
		.clk(clk),
		.request({l2req_valid_core1, l2req_valid_core0}),
		.update_lru(1),	// XXX not always quite right
		.grant_oh({l2grant_core0, l2grant_core1}));

	core core0(
		.halt_o(processor_halt0),
		.l2req_valid(l2req_valid_core0),
		.l2req_strand(l2req_strand_core0),
		.l2req_unit(l2req_unit_core0),
		.l2req_op(l2req_op_core0),
		.l2req_way(l2req_way_core0),
		.l2req_address(l2req_address_core0),
		.l2req_data(l2req_data_core0),
		.l2req_mask(l2req_mask_core0),

		/*AUTOINST*/
		   // Inputs
		   .clk			(clk),
		   .l2req_ack		(l2req_ack),
		   .l2rsp_valid		(l2rsp_valid),
		   .l2rsp_status	(l2rsp_status),
		   .l2rsp_unit		(l2rsp_unit[1:0]),
		   .l2rsp_strand	(l2rsp_strand[1:0]),
		   .l2rsp_op		(l2rsp_op[1:0]),
		   .l2rsp_update	(l2rsp_update),
		   .l2rsp_way		(l2rsp_way[1:0]),
		   .l2rsp_data		(l2rsp_data[511:0]));

	core core1(
		.halt_o(processor_halt1),
		.l2req_valid(l2req_valid_core1),
		.l2req_strand(l2req_strand_core1),
		.l2req_unit(l2req_unit_core1),
		.l2req_op(l2req_op_core1),
		.l2req_way(l2req_way_core1),
		.l2req_address(l2req_address_core1),
		.l2req_data(l2req_data_core1),
		.l2req_mask(l2req_mask_core1),

		/*AUTOINST*/
		   // Inputs
		   .clk			(clk),
		   .l2req_ack		(l2req_ack),
		   .l2rsp_valid		(l2rsp_valid),
		   .l2rsp_status	(l2rsp_status),
		   .l2rsp_unit		(l2rsp_unit[1:0]),
		   .l2rsp_strand	(l2rsp_strand[1:0]),
		   .l2rsp_op		(l2rsp_op[1:0]),
		   .l2rsp_update	(l2rsp_update),
		   .l2rsp_way		(l2rsp_way[1:0]),
		   .l2rsp_data		(l2rsp_data[511:0]));


	l2_cache l2_cache(
			  .l2req_core		(2'd0),	// Only one core now
				/*AUTOINST*/
			  // Outputs
			  .l2req_ack		(l2req_ack),
			  .l2rsp_valid		(l2rsp_valid),
			  .l2rsp_status		(l2rsp_status),
			  .l2rsp_core		(l2rsp_core[1:0]),
			  .l2rsp_unit		(l2rsp_unit[1:0]),
			  .l2rsp_strand		(l2rsp_strand[1:0]),
			  .l2rsp_op		(l2rsp_op[1:0]),
			  .l2rsp_update		(l2rsp_update),
			  .l2rsp_way		(l2rsp_way[1:0]),
			  .l2rsp_data		(l2rsp_data[511:0]),
			  .axi_awaddr		(axi_awaddr[31:0]),
			  .axi_awlen		(axi_awlen[7:0]),
			  .axi_awvalid		(axi_awvalid),
			  .axi_wdata		(axi_wdata[31:0]),
			  .axi_wlast		(axi_wlast),
			  .axi_wvalid		(axi_wvalid),
			  .axi_bready		(axi_bready),
			  .axi_araddr		(axi_araddr[31:0]),
			  .axi_arlen		(axi_arlen[7:0]),
			  .axi_arvalid		(axi_arvalid),
			  .axi_rready		(axi_rready),
			  // Inputs
			  .clk			(clk),
			  .l2req_valid		(l2req_valid),
			  .l2req_unit		(l2req_unit[1:0]),
			  .l2req_strand		(l2req_strand[1:0]),
			  .l2req_op		(l2req_op[2:0]),
			  .l2req_way		(l2req_way[1:0]),
			  .l2req_address	(l2req_address[25:0]),
			  .l2req_data		(l2req_data[511:0]),
			  .l2req_mask		(l2req_mask[63:0]),
			  .axi_awready		(axi_awready),
			  .axi_wready		(axi_wready),
			  .axi_bvalid		(axi_bvalid),
			  .axi_arready		(axi_arready),
			  .axi_rvalid		(axi_rvalid),
			  .axi_rdata		(axi_rdata[31:0]));

	sim_memory memory(/*AUTOINST*/
			  // Outputs
			  .axi_awready		(axi_awready),
			  .axi_wready		(axi_wready),
			  .axi_bvalid		(axi_bvalid),
			  .axi_arready		(axi_arready),
			  .axi_rvalid		(axi_rvalid),
			  .axi_rdata		(axi_rdata[31:0]),
			  // Inputs
			  .clk			(clk),
			  .axi_awaddr		(axi_awaddr[31:0]),
			  .axi_awlen		(axi_awlen[7:0]),
			  .axi_awvalid		(axi_awvalid),
			  .axi_wdata		(axi_wdata[31:0]),
			  .axi_wlast		(axi_wlast),
			  .axi_wvalid		(axi_wvalid),
			  .axi_bready		(axi_bready),
			  .axi_araddr		(axi_araddr[31:0]),
			  .axi_arlen		(axi_arlen[7:0]),
			  .axi_arvalid		(axi_arvalid),
			  .axi_rready		(axi_rready));

	initial
	begin
		// Load executable binary into memory
		if ($value$plusargs("bin=%s", filename))
			$readmemh(filename, memory.memory);
		else
		begin
			$display("error opening file");
			$finish;
		end

		do_register_dump = 0; // Dump all registers at end

		`define PIPELINE core0.pipeline
		`define SS_STAGE `PIPELINE.strand_select_stage
		`define VREG_FILE `PIPELINE.vector_register_file
		`define SFSM0 `SS_STAGE.strand_fsm0
		`define SFSM1 `SS_STAGE.strand_fsm1
		`define SFSM2 `SS_STAGE.strand_fsm2
		`define SFSM3 `SS_STAGE.strand_fsm3

		// If initial values are passed for scalar registers, load those now
		if ($value$plusargs("initial_regs=%s", filename))
		begin
			$readmemh(filename, regtemp);
			for (i = 0; i < NUM_REGS * NUM_STRANDS; i = i + 1)		// ignore PC
				`PIPELINE.scalar_register_file.registers[i] = regtemp[i];

			for (i = 0; i < NUM_REGS * NUM_STRANDS; i = i + 1)
			begin
				`VREG_FILE.lane15[i] = regtemp[(i + 8) * 16];
				`VREG_FILE.lane14[i] = regtemp[(i + 8) * 16 + 1];
				`VREG_FILE.lane13[i] = regtemp[(i + 8) * 16 + 2];
				`VREG_FILE.lane12[i] = regtemp[(i + 8) * 16 + 3];
				`VREG_FILE.lane11[i] = regtemp[(i + 8) * 16 + 4];
				`VREG_FILE.lane10[i] = regtemp[(i + 8) * 16 + 5];
				`VREG_FILE.lane9[i] = regtemp[(i + 8) * 16 + 6];
				`VREG_FILE.lane8[i] = regtemp[(i + 8) * 16 + 7];
				`VREG_FILE.lane7[i] = regtemp[(i + 8) * 16 + 8];
				`VREG_FILE.lane6[i] = regtemp[(i + 8) * 16 + 9];
				`VREG_FILE.lane5[i] = regtemp[(i + 8) * 16 + 10];
				`VREG_FILE.lane4[i] = regtemp[(i + 8) * 16 + 11];
				`VREG_FILE.lane3[i] = regtemp[(i + 8) * 16 + 12];
				`VREG_FILE.lane2[i] = regtemp[(i + 8) * 16 + 13];
				`VREG_FILE.lane1[i] = regtemp[(i + 8) * 16 + 14];
				`VREG_FILE.lane0[i] = regtemp[(i + 8) * 16 + 15];
			end
			
			do_register_dump = 1;
		end

		if ($value$plusargs("statetrace=%s", filename))
		begin
			state_trace_fp = $fopen(filename, "w");
			do_state_trace = 1;
		end
		else
			do_state_trace = 0;

		if (!$value$plusargs("regtrace=%d", do_register_trace))
			do_register_trace = 0;
	
		// Open a waveform dump trace file
		if ($value$plusargs("trace=%s", filename))
		begin
			$dumpfile(filename);
			$dumpvars;
		end
	
		// Run simulation for some number of cycles
		if (!$value$plusargs("simcycles=%d", simulation_cycles))
			simulation_cycles = 500;

		if (do_register_trace)
		begin
			clk = 0;
			for (i = 0; i < simulation_cycles && !processor_halt; i = i + 1)
			begin
				#5 clk = 1;
				#5 clk = 0;
				
				wb_pc <= core0.pipeline.ma_pc;

				// Display register dump
				if (core0.pipeline.wb_has_writeback)
				begin
					if (core0.pipeline.wb_writeback_is_vector)
					begin
						$display("%08x [st %d] v%d{%04x} <= %128x", 
							wb_pc - 4, 
							core0.pipeline.wb_writeback_reg[6:5], 
							core0.pipeline.wb_writeback_reg[4:0], 
							core0.pipeline.wb_writeback_mask,
							core0.pipeline.wb_writeback_value);
					end
					else
					begin
						$display("%08x [st %d] s%d <= %8x", 
							wb_pc - 4, 
							core0.pipeline.wb_writeback_reg[6:5], 
							core0.pipeline.wb_writeback_reg[4:0], 
							core0.pipeline.wb_writeback_value[31:0]);
					end
				end
			end
		end
		else
		begin
			clk = 0;
			for (i = 0; i < simulation_cycles && !processor_halt; i = i + 1)
			begin
				#5 clk = 1;
				#5 clk = 0;
				
				if (do_state_trace >= 0)
				begin
					$fwrite(state_trace_fp, "%d,%d,%d,%d,%d,%d,%d,%d\n", 
						`SS_STAGE.strand_fsm0.instruction_valid_i,
						`SS_STAGE.strand_fsm0.thread_state_ff,
						`SS_STAGE.strand_fsm1.instruction_valid_i,
						`SS_STAGE.strand_fsm1.thread_state_ff,
						`SS_STAGE.strand_fsm2.instruction_valid_i,
						`SS_STAGE.strand_fsm2.thread_state_ff,
						`SS_STAGE.strand_fsm3.instruction_valid_i,
						`SS_STAGE.strand_fsm3.thread_state_ff);
				end
			end
		end
		
		if (do_state_trace >= 0)
			$fclose(state_trace_fp);

		if (processor_halt)
			$display("***HALTED***");

		$display("ran for %d cycles", i);
		$display(" instructions issued %d", `SS_STAGE.issue_count);
		$display(" instructions retired %d", `PIPELINE.writeback_stage.retire_count);
		$display("strand states:");
		$display(" RAW conflict %d", 
			`SFSM0.raw_wait_count
			+ `SFSM1.raw_wait_count
			+ `SFSM2.raw_wait_count
			+ `SFSM3.raw_wait_count);
		$display(" wait for dcache/store %d", 
			`SFSM0.dcache_wait_count
			+ `SFSM1.dcache_wait_count
			+ `SFSM2.dcache_wait_count
			+ `SFSM3.dcache_wait_count);
		$display(" wait for icache %d", 
			`SFSM0.icache_wait_count
			+ `SFSM1.icache_wait_count
			+ `SFSM2.icache_wait_count
			+ `SFSM3.icache_wait_count);
		$display("L1 icache hits %d misses %d", 
			core0.icache.hit_count, core0.icache.miss_count);
		$display("L1 dcache hits %d misses %d", 
			core0.dcache.hit_count, core0.dcache.miss_count);
		$display("L1 store count %d",
			core0.store_buffer.store_count);
		$display("L2 cache hits %d misses %d",
			l2_cache.hit_count, l2_cache.miss_count);

		if (do_register_dump)
		begin
			$display("REGISTERS:");
			// Dump the registers
			for (i = 0; i < NUM_REGS * NUM_STRANDS; i = i + 1)
				$display("%08x", `PIPELINE.scalar_register_file.registers[i]);
	
			for (i = 0; i < NUM_REGS * NUM_STRANDS; i = i + 1)
			begin
				$display("%08x", `PIPELINE.vector_register_file.lane15[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane14[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane13[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane12[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane11[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane10[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane9[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane8[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane7[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane6[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane5[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane4[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane3[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane2[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane1[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane0[i]);
			end
		end

		if ($value$plusargs("autoflushl2=%d", do_autoflush_l2))
			sync_l2_cache;

		if ($value$plusargs("memdumpbase=%x", mem_dump_start)
			&& $value$plusargs("memdumplen=%x", mem_dump_length)
			&& $value$plusargs("memdumpfile=%s", filename))
		begin
			fp = $fopen(filename, "wb");
			for (i = 0; i < mem_dump_length; i = i + 4)
			begin
				mem_dat = memory.memory[(mem_dump_start + i) / 4];
				dummy_return = $fputc(mem_dat[31:24], fp);
				dummy_return = $fputc(mem_dat[23:16], fp);
				dummy_return = $fputc(mem_dat[15:8], fp);
				dummy_return = $fputc(mem_dat[7:0], fp);
			end

			$fclose(fp);
		end
	end

	// Manually copy lines from the L2 cache back to memory so we can
	// validate it there.
	reg[`L2_SET_INDEX_WIDTH - 1:0] set_index;
	reg[3:0] line_offset;
	reg[`L2_TAG_WIDTH - 1:0] flush_tag;
	integer set_index_count;
	integer line_offset_count;

	task sync_l2_cache;
	begin
		for (set_index_count = 0; set_index_count < `L2_NUM_SETS; set_index_count
			= set_index_count + 1)
		begin
			set_index = set_index_count;
	
			if (l2_cache.l2_cache_tag.l2_valid_mem0.data[set_index])
			begin
				flush_tag = l2_cache.l2_cache_tag.l2_tag_mem0.data[set_index];
				for (line_offset_count = 0; line_offset_count < 16; line_offset_count 
					= line_offset_count + 1)
				begin
					line_offset = line_offset_count;
					memory.memory[{ flush_tag, set_index, line_offset }] = 
						l2_cache.l2_cache_read.cache_mem.data[{ 2'd0, set_index }]
						 >> ((15 - line_offset) * 32);
				end
			end

			if (l2_cache.l2_cache_tag.l2_valid_mem1.data[set_index])
			begin
				flush_tag = l2_cache.l2_cache_tag.l2_tag_mem1.data[set_index];
				for (line_offset_count = 0; line_offset_count < 16; line_offset_count 
					= line_offset_count + 1)
				begin
					line_offset = line_offset_count;
					memory.memory[{ flush_tag, set_index, line_offset }] = 
						l2_cache.l2_cache_read.cache_mem.data[{ 2'd1, set_index }]
						 >> ((15 - line_offset) * 32);
				end
			end

			if (l2_cache.l2_cache_tag.l2_valid_mem2.data[set_index])
			begin
				flush_tag = l2_cache.l2_cache_tag.l2_tag_mem2.data[set_index];
				for (line_offset_count = 0; line_offset_count < 16; line_offset_count 
					= line_offset_count + 1)
				begin
					line_offset = line_offset_count;
					memory.memory[{ flush_tag, set_index, line_offset }] = 
						l2_cache.l2_cache_read.cache_mem.data[{ 2'd2, set_index }]
						 >> ((15 - line_offset) * 32);
				end
			end

			if (l2_cache.l2_cache_tag.l2_valid_mem3.data[set_index])
			begin
				flush_tag = l2_cache.l2_cache_tag.l2_tag_mem3.data[set_index];
				for (line_offset_count = 0; line_offset_count < 16; line_offset_count 
					= line_offset_count + 1)
				begin
					line_offset = line_offset_count;
					memory.memory[{ flush_tag, set_index, line_offset }] = 
						l2_cache.l2_cache_read.cache_mem.data[{ 2'd3, set_index }]
						 >> ((15 - line_offset) * 32);
				end
			end
		end
	end
	endtask
endmodule

// Local Variables:
// verilog-library-flags:("-y ../rtl")
// End: