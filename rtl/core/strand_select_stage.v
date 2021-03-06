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

`include "instruction_format.h"

//
// CPU pipeline strand selection stage.
// Each cycle, this will select a strand to issue to the decode stage.  It 
// detects and schedules around conflicts in the pipeline and tracks
// which strands are waiting (for example, on data cache misses)
//

module strand_select_stage(
	input					clk,
	input					reset,

	// From control register unit
	input [3:0]				strand_enable,

	// Inputs from instruction fetch stage
	input [31:0]			if_instruction0,
	input					if_instruction_valid0,
	input [31:0]			if_pc0,
	input					if_branch_predicted0,
	input					if_long_latency0,
	input					rb_rollback_strand0,
	input					rb_retry_strand0,
	input					suspend_strand0,
	input					resume_strand0,
	output					ss_instruction_req0,
	input [31:0]			rollback_strided_offset0,
	input [3:0]				rollback_reg_lane0,

	input [31:0]			if_instruction1,
	input					if_instruction_valid1,
	input [31:0]			if_pc1,
	input					if_branch_predicted1,
	input					if_long_latency1,
	input					rb_rollback_strand1,
	input					rb_retry_strand1,
	input					suspend_strand1,
	input					resume_strand1,
	output					ss_instruction_req1,
	input [31:0]			rollback_strided_offset1,
	input [3:0]				rollback_reg_lane1,

	input [31:0]			if_instruction2,
	input					if_instruction_valid2,
	input [31:0]			if_pc2,
	input					if_branch_predicted2,
	input					if_long_latency2,
	input					rb_rollback_strand2,
	input					rb_retry_strand2,
	input					suspend_strand2,
	input					resume_strand2,
	output					ss_instruction_req2,
	input [31:0]			rollback_strided_offset2,
	input [3:0]				rollback_reg_lane2,

	input [31:0]			if_instruction3,
	input					if_instruction_valid3,
	input [31:0]			if_pc3,
	input					if_branch_predicted3,
	input					if_long_latency3,
	input					rb_rollback_strand3,
	input					rb_retry_strand3,
	input					suspend_strand3,
	input					resume_strand3,
	output					ss_instruction_req3,
	input [31:0]			rollback_strided_offset3,
	input [3:0]				rollback_reg_lane3,

	// Outputs to decode stage.
	output reg[31:0]		ss_pc,
	output reg[31:0]		ss_instruction,
	output reg[3:0]			ss_reg_lane_select,
	output reg[31:0]		ss_strided_offset,
	output reg[1:0]			ss_strand,
	output reg				ss_branch_predicted,
	output reg				ss_long_latency);

	wire[3:0] reg_lane_select0;
	wire[31:0] strided_offset0;
	wire[3:0] reg_lane_select1;
	wire[31:0] strided_offset1;
	wire[3:0] reg_lane_select2;
	wire[31:0] strided_offset2;
	wire[3:0] reg_lane_select3;
	wire[31:0] strided_offset3;
	wire[3:0] strand_ready;
	wire[3:0] issue_strand_oh;
	wire[3:0] execute_hazard;
	reg[63:0] issue_count;

	wire short_latency0 = !if_long_latency0 && if_instruction0 != `NOP;
	wire short_latency1 = !if_long_latency1 && if_instruction1 != `NOP;
	wire short_latency2 = !if_long_latency2 && if_instruction2 != `NOP;
	wire short_latency3 = !if_long_latency3 && if_instruction3 != `NOP;

	// Detect conflicts at the end of the execute stage where the long and
	// short pipelines merge and avoid scheduling instructions that would
	// conflict.
	execute_hazard_detect ehd(
		.issue_oh(issue_strand_oh),
		.short_latency({ short_latency3, short_latency2, short_latency1, short_latency0 }), 
		.long_latency({ if_long_latency3, if_long_latency2, if_long_latency1, if_long_latency0 }),
		/*AUTOINST*/
				  // Outputs
				  .execute_hazard	(execute_hazard[3:0]),
				  // Inputs
				  .clk			(clk),
				  .reset		(reset));
	
	strand_fsm strand_fsm0(
		.instruction_i(if_instruction0),
		.long_latency(if_long_latency0),
		.instruction_valid_i(if_instruction_valid0),
		.issue(issue_strand_oh[0]),
		.ready(strand_ready[0]),
		.flush_i(rb_rollback_strand0),
		.retry_i(rb_retry_strand0),
		.next_instr_request(ss_instruction_req0),
		.suspend_strand_i(suspend_strand0),
		.resume_strand_i(resume_strand0),
		.rollback_strided_offset_i(rollback_strided_offset0),
		.rollback_reg_lane_i(rollback_reg_lane0),
		.reg_lane_select_o(reg_lane_select0),
		.strided_offset_o(strided_offset0),
		/*AUTOINST*/
			       // Inputs
			       .clk		(clk),
			       .reset		(reset));

	strand_fsm strand_fsm1(
		.instruction_i(if_instruction1),
		.long_latency(if_long_latency1),
		.instruction_valid_i(if_instruction_valid1),
		.issue(issue_strand_oh[1]),
		.ready(strand_ready[1]),
		.flush_i(rb_rollback_strand1),
		.retry_i(rb_retry_strand1),
		.next_instr_request(ss_instruction_req1),
		.suspend_strand_i(suspend_strand1),
		.resume_strand_i(resume_strand1),
		.rollback_strided_offset_i(rollback_strided_offset1),
		.rollback_reg_lane_i(rollback_reg_lane1),
		.reg_lane_select_o(reg_lane_select1),
		.strided_offset_o(strided_offset1),
		/*AUTOINST*/
			       // Inputs
			       .clk		(clk),
			       .reset		(reset));

	strand_fsm strand_fsm2(
		.instruction_i(if_instruction2),
		.long_latency(if_long_latency2),
		.instruction_valid_i(if_instruction_valid2),
		.issue(issue_strand_oh[2]),
		.ready(strand_ready[2]),
		.flush_i(rb_rollback_strand2),
		.retry_i(rb_retry_strand2),
		.next_instr_request(ss_instruction_req2),
		.suspend_strand_i(suspend_strand2),
		.resume_strand_i(resume_strand2),
		.rollback_strided_offset_i(rollback_strided_offset2),
		.rollback_reg_lane_i(rollback_reg_lane2),
		.reg_lane_select_o(reg_lane_select2),
		.strided_offset_o(strided_offset2),
		/*AUTOINST*/
			       // Inputs
			       .clk		(clk),
			       .reset		(reset));

	strand_fsm strand_fsm3(
		.instruction_i(if_instruction3),
		.long_latency(if_long_latency3),
		.instruction_valid_i(if_instruction_valid3),
		.issue(issue_strand_oh[3]),
		.ready(strand_ready[3]),
		.flush_i(rb_rollback_strand3),
		.retry_i(rb_retry_strand3),
		.next_instr_request(ss_instruction_req3),
		.suspend_strand_i(suspend_strand3),
		.resume_strand_i(resume_strand3),
		.rollback_strided_offset_i(rollback_strided_offset3),
		.rollback_reg_lane_i(rollback_reg_lane3),
		.reg_lane_select_o(reg_lane_select3),
		.strided_offset_o(strided_offset3),
		/*AUTOINST*/
			       // Inputs
			       .clk		(clk),
			       .reset		(reset));

	arbiter #(4) issue_arbiter(
		.request(strand_ready & strand_enable & ~execute_hazard),
		.update_lru(1'b1),
		.grant_oh(issue_strand_oh),
		/*AUTOINST*/
				   // Inputs
				   .clk			(clk),
				   .reset		(reset));

	wire[1:0] issue_strand_idx = { issue_strand_oh[3] || issue_strand_oh[2],
		issue_strand_oh[3] || issue_strand_oh[1] };

	// Output mux
	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			issue_count <= 64'h0;
			ss_branch_predicted <= 1'h0;
			ss_instruction <= 32'h0;
			ss_long_latency <= 1'h0;
			ss_pc <= 32'h0;
			ss_reg_lane_select <= 4'h0;
			ss_strand <= 2'h0;
			ss_strided_offset <= 32'h0;
			// End of automatics
		end
		else
		begin
			if (issue_strand_oh != 0)
			begin
				case (issue_strand_idx)
					0:
					begin
						ss_pc				<= if_pc0;
						ss_instruction		<= if_instruction0;
						ss_branch_predicted <= if_branch_predicted0;
						ss_long_latency 	<= if_long_latency0;
						ss_reg_lane_select	<= reg_lane_select0;
						ss_strided_offset	<= strided_offset0;
					end
					
					1:
					begin
						ss_pc				<= if_pc1;
						ss_instruction		<= if_instruction1;
						ss_branch_predicted <= if_branch_predicted1;
						ss_long_latency 	<= if_long_latency1;
						ss_reg_lane_select	<= reg_lane_select1;
						ss_strided_offset	<= strided_offset1;
					end
					
					2:
					begin
						ss_pc				<= if_pc2;
						ss_instruction		<= if_instruction2;
						ss_branch_predicted <= if_branch_predicted2;
						ss_long_latency 	<= if_long_latency2;
						ss_reg_lane_select	<= reg_lane_select2;
						ss_strided_offset	<= strided_offset2;
					end
					
					3:
					begin
						ss_pc				<= if_pc3;
						ss_instruction		<= if_instruction3;
						ss_branch_predicted <= if_branch_predicted3;
						ss_long_latency 	<= if_long_latency3;
						ss_reg_lane_select	<= reg_lane_select3;
						ss_strided_offset	<= strided_offset3;
					end
				endcase
				
				issue_count <= issue_count + 1;
				ss_strand <= issue_strand_idx;
			end
			else
			begin
				// No strand is ready, issue NOP
				ss_pc 				<= 0;
				ss_instruction 		<= `NOP;
				ss_branch_predicted <= 0;
				ss_long_latency 	<= 0;
			end
		end

`ifdef GENERATE_PROFILE_DATA
		if (ss_instruction != 0)
			$display("%08x", ss_pc);
`endif
	end
endmodule
