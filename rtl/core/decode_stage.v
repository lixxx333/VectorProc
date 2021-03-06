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
`include "decode.h"

//
// CPU pipeline instruction decode stage
// - Maps register addresses to register file ports and issues request to latter.
// - Decodes writeback destination, which will be propagated down the pipeline
//   for bypassing.
//
// Register port to operand mapping
//                                               store 
//       format           op1     op2    mask    value
// +-------------------+-------+-------+-------+-------+
// | A - scalar/scalar |   s1  |   s2  |       |       |
// | A - vector/scalar |   v1  |   s2  |  s1   |       |
// | A - vector/vector |   v1  |   v2  |  s2   |       |
// | B - scalar        |   s1  |  imm  |  n/a  |       |
// | B - vector        |   v1  |  imm  |  s2   |       |
// | C - scalar        |   s1  |  imm  |  n/a  |  s2   |
// | C - block         |   s1  |  imm  |  s2   |  v2   |
// | C - strided       |   s1  |  imm  |  s2   |  v2   |
// | C - scatter/gather|   v1  |  imm  |  s2   |  v2   |
// | D                 |   s1  |  imm  |       |       |
// | E                 |   s1  |       |       |       |
// +-------------------+-------+-------+-------+-------+
//

module decode_stage(
	input					clk,
	input					reset,

	// From rollback controller
	input					squash_ds,

	// From strand select stage
	input[31:0]				ss_instruction,
	input[1:0]				ss_strand,
	input					ss_branch_predicted,
	input [31:0]			ss_pc,
	input [31:0]			ss_strided_offset,
	input					ss_long_latency,
	input [3:0]				ss_reg_lane_select,

	// To register file
	output reg[6:0]			ds_scalar_sel1,
	output reg[6:0]			ds_scalar_sel2,
	output wire[6:0]		ds_vector_sel1,
	output reg[6:0]			ds_vector_sel2,

	// To execute stage
	output reg[31:0]		ds_instruction,
	output reg[1:0]			ds_strand,
	output reg[31:0]		ds_pc,
	output reg[31:0]		ds_immediate_value,
	output reg[2:0]			ds_mask_src,
	output reg				ds_op1_is_vector,
	output reg[1:0]			ds_op2_src,
	output reg				ds_store_value_is_vector,
	output reg [6:0]		ds_writeback_reg,
	output reg				ds_enable_scalar_writeback,
	output reg 				ds_enable_vector_writeback,
	output reg[5:0]			ds_alu_op,
	output reg[3:0]			ds_reg_lane_select,
	output reg[31:0]		ds_strided_offset,
	output reg				ds_branch_predicted,
	output reg				ds_long_latency,
	output reg[6:0] 		ds_vector_sel1_l,
	output reg[6:0] 		ds_vector_sel2_l,
	output reg[6:0] 		ds_scalar_sel1_l,
	output reg[6:0] 		ds_scalar_sel2_l);
	
	// Instruction Fields
	wire[4:0] src1_reg = ss_instruction[4:0];
	wire[4:0] src2_reg = ss_instruction[19:15];
	wire[4:0] mask_reg = ss_instruction[14:10];
	wire[4:0] dest_reg = ss_instruction[9:5];
	wire[2:0] a_fmt = ss_instruction[22:20];
	wire[5:0] a_opcode = ss_instruction[28:23];
	wire[2:0] b_fmt = ss_instruction[25:23];
	wire[4:0] b_opcode = ss_instruction[30:26];
	wire[31:0] b_immediate = { {24{ss_instruction[22]}}, ss_instruction[22:15] };
	wire[31:0] b_extended_immediate = { {19{ss_instruction[22]}}, ss_instruction[22:10] };
	wire[3:0] c_op = ss_instruction[28:25];
	wire[31:0] c_offset = { {22{ss_instruction[24]}}, ss_instruction[24:15] };

	// Decode logic
	wire is_fmt_a = ss_instruction[31:29] == 3'b110;	
	wire is_fmt_b = ss_instruction[31] == 1'b0;	
	wire is_fmt_c = ss_instruction[31:30] == 2'b10;	
	wire is_vector_memory_transfer = c_op[3] == 1'b1 || c_op == `MEM_BLOCK;
	wire is_load = ss_instruction[29];	// Assumes is op c
	wire is_call = ss_instruction[31:25] == { 4'b1111, `BRANCH_CALL_OFFSET } 
		|| ss_instruction[31:25] == { 4'b1111, `BRANCH_CALL_REGISTER};

	reg writeback_is_vector;
	reg[5:0] alu_op_nxt;
	reg[31:0] immediate_nxt;
	reg op1_is_vector_nxt;
	reg[1:0] op2_src_nxt;
	reg[2:0] mask_src_nxt;

	always @*
	begin
		if (is_fmt_b)
		begin
			if (b_fmt == `FMTB_V_V_M 
				|| b_fmt == `FMTB_V_V_IM 
				|| b_fmt == `FMTB_V_S_M 
				|| b_fmt == `FMTB_V_S_IM)
				immediate_nxt = b_immediate;
			else
				immediate_nxt = b_extended_immediate;	// If there's no mask field, use it as part of immediate 
		end
		else // Format C, format D or don't care
			immediate_nxt = c_offset;
	end

	// Note that the register port selects are not registered, because the 
	// register file has one cycle of latency.  The registered outputs and 
	// the register fetch results will arrive at the same time to the
	// execute stage.

	always @*
	begin
		if (is_fmt_a && (a_fmt == `FMTA_V_S 
			|| a_fmt == `FMTA_V_S_M
			|| a_fmt == `FMTA_V_S_IM))
		begin
			// A bit of a special case: since we are already using s2
			// to read the scalar operand, need to use s1 for the mask.
			ds_scalar_sel1 = { ss_strand, mask_reg };
		end
		else
			ds_scalar_sel1 = { ss_strand, src1_reg };
	end

	always @*
	begin
		if (is_fmt_c && !is_load && !is_vector_memory_transfer)
			ds_scalar_sel2 = { ss_strand, dest_reg };
		else if (is_fmt_a && (a_fmt == `FMTA_S 
			|| a_fmt == `FMTA_V_S
			|| a_fmt == `FMTA_V_S_M 
			|| a_fmt == `FMTA_V_S_IM))
		begin
			ds_scalar_sel2 = { ss_strand, src2_reg };	// src2
		end
		else
			ds_scalar_sel2 = { ss_strand, mask_reg };	// mask
	end

	assign ds_vector_sel1 = { ss_strand, src1_reg };
	
	always @*
	begin
		if (is_fmt_a && (a_fmt == `FMTA_V_V 
			|| a_fmt == `FMTA_V_V_M
			|| a_fmt == `FMTA_V_V_IM))
			ds_vector_sel2 = { ss_strand, src2_reg };	// src2
		else
			ds_vector_sel2 = { ss_strand, dest_reg }; // store value
	end

	always @*
	begin
		if (is_fmt_a)
			op1_is_vector_nxt = a_fmt != `FMTA_S;
		else if (is_fmt_b)
		begin
			op1_is_vector_nxt = b_fmt == `FMTB_V_V
				|| b_fmt == `FMTB_V_V_M
				|| b_fmt == `FMTB_V_V_IM;
		end
		else if (is_fmt_c)
			op1_is_vector_nxt = c_op == `MEM_SCGATH 
				|| c_op == `MEM_SCGATH_M
				|| c_op == `MEM_SCGATH_IM;
		else
			op1_is_vector_nxt = 1'b0;
	end

	always @*
	begin
		if (is_fmt_a)
		begin
			if (a_fmt == `FMTA_V_V
				|| a_fmt == `FMTA_V_V_M
				|| a_fmt == `FMTA_V_V_IM)
				op2_src_nxt = `OP2_SRC_VECTOR2;	// Vector operand
			else
				op2_src_nxt = `OP2_SRC_SCALAR2;	// Scalar operand
		end
		else	// Format B or C or don't care
			op2_src_nxt = `OP2_SRC_IMMEDIATE;	// Immediate operand
	end
	
	always @*
	begin
		if (is_fmt_a)
		begin
			// Register arithmetic instructions
			case (a_fmt)
				`FMTA_S:		mask_src_nxt = `MASK_SRC_ALL_ONES;	
				`FMTA_V_S: 		mask_src_nxt = `MASK_SRC_ALL_ONES;
				`FMTA_V_S_M: 	mask_src_nxt = `MASK_SRC_SCALAR1;
				`FMTA_V_S_IM: 	mask_src_nxt = `MASK_SRC_SCALAR1_INV;
				`FMTA_V_V: 		mask_src_nxt = `MASK_SRC_ALL_ONES;
				`FMTA_V_V_M: 	mask_src_nxt = `MASK_SRC_SCALAR2;
				`FMTA_V_V_IM: 	mask_src_nxt = `MASK_SRC_SCALAR2_INV;
				default: 		mask_src_nxt = `MASK_SRC_SCALAR1; // Invalid type
			endcase
		end
		else if (is_fmt_b)
		begin
			// Immediate arithmetic instructions
			case (b_fmt)
				`FMTB_S_S: 		mask_src_nxt = `MASK_SRC_ALL_ONES;	
				`FMTB_V_V: 		mask_src_nxt = `MASK_SRC_ALL_ONES;	
				`FMTB_V_V_M: 	mask_src_nxt = `MASK_SRC_SCALAR2;	
				`FMTB_V_V_IM:	mask_src_nxt = `MASK_SRC_SCALAR2_INV;	
				`FMTB_V_S:		mask_src_nxt = `MASK_SRC_ALL_ONES;	
				`FMTB_V_S_M: 	mask_src_nxt = `MASK_SRC_SCALAR2;	
				`FMTB_V_S_IM: 	mask_src_nxt = `MASK_SRC_SCALAR2_INV;	
				default: 		mask_src_nxt = `MASK_SRC_ALL_ONES;	// Invalid type
			endcase
		end
		else if (is_fmt_c)
		begin
			// Memory access
			case (c_op)
				`MEM_B: 			mask_src_nxt = `MASK_SRC_ALL_ONES;	// Scalar Access
				`MEM_BX: 			mask_src_nxt = `MASK_SRC_ALL_ONES;
				`MEM_S: 			mask_src_nxt = `MASK_SRC_ALL_ONES;
				`MEM_SX: 			mask_src_nxt = `MASK_SRC_ALL_ONES;
				`MEM_L: 			mask_src_nxt = `MASK_SRC_ALL_ONES;		
				`MEM_SYNC: 			mask_src_nxt = `MASK_SRC_ALL_ONES;	// synchronized
				`MEM_CONTROL_REG:	mask_src_nxt = `MASK_SRC_ALL_ONES;	// Control reigster transfer
				`MEM_BLOCK: 		mask_src_nxt = `MASK_SRC_ALL_ONES;	// Block vector access
				`MEM_BLOCK_M: 		mask_src_nxt = `MASK_SRC_SCALAR2;
				`MEM_BLOCK_IM: 		mask_src_nxt = `MASK_SRC_SCALAR2_INV;
				`MEM_STRIDED: 		mask_src_nxt = `MASK_SRC_ALL_ONES; 	// Strided vector access		
				`MEM_STRIDED_M: 	mask_src_nxt = `MASK_SRC_SCALAR2;
				`MEM_STRIDED_IM: 	mask_src_nxt = `MASK_SRC_SCALAR2_INV;
				`MEM_SCGATH: 		mask_src_nxt = `MASK_SRC_ALL_ONES;	// Scatter/Gather			
				`MEM_SCGATH_M: 		mask_src_nxt = `MASK_SRC_SCALAR2;
				`MEM_SCGATH_IM: 	mask_src_nxt = `MASK_SRC_SCALAR2_INV;
			endcase
		end
		else
			mask_src_nxt = `MASK_SRC_ALL_ONES;
	end
	
	wire store_value_is_vector_nxt = !(is_fmt_c && !is_vector_memory_transfer);

	always @*
	begin
		if (is_fmt_a)
			alu_op_nxt = a_opcode;
		else if (is_fmt_b)
			alu_op_nxt = b_opcode;
		else 
			alu_op_nxt = `OP_IADD;	// Addition (for offsets)
	end

	wire has_writeback = (is_fmt_a 
		|| is_fmt_b 
		|| (is_fmt_c && is_load) 		// Load
		|| (is_fmt_c && c_op == `MEM_SYNC)	// Synchronized load/store
		|| is_call)
		&& ss_instruction != `NOP;	// XXX check for nop for debugging

	wire[6:0] writeback_reg_nxt = is_call ? { ss_strand, `REG_LINK }
		: { ss_strand, dest_reg };

	always @*
	begin
		if (is_fmt_a)
		begin
			if ((a_opcode >= `OP_EQUAL && a_opcode <= `OP_UILTE) 
				|| (a_opcode >= `OP_FGTR && a_opcode <= `OP_FLTE)
				|| a_opcode == `OP_GETLANE)
				writeback_is_vector = 0;	// compare op or getlane
			else
				writeback_is_vector = a_fmt != `FMTA_S;
		end
		else if (is_fmt_b)
		begin
			if ((b_opcode >= `OP_EQUAL && b_opcode <= `OP_UILTE) 
				|| (b_opcode >= `OP_FGTR && b_opcode <= `OP_FLTE)
				|| b_opcode == `OP_GETLANE)
				writeback_is_vector = 0;	// compare op or getlane (a bit special)
			else
				writeback_is_vector = b_fmt != `FMTB_S_S;
		end
		else if (is_call)
			writeback_is_vector = 0;
		else // is_fmt_c or don't care...
			writeback_is_vector = is_vector_memory_transfer;
	end

	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			ds_alu_op <= 6'h0;
			ds_branch_predicted <= 1'h0;
			ds_enable_scalar_writeback <= 1'h0;
			ds_enable_vector_writeback <= 1'h0;
			ds_immediate_value <= 32'h0;
			ds_instruction <= 32'h0;
			ds_long_latency <= 1'h0;
			ds_mask_src <= 3'h0;
			ds_op1_is_vector <= 1'h0;
			ds_op2_src <= 2'h0;
			ds_pc <= 32'h0;
			ds_reg_lane_select <= 4'h0;
			ds_scalar_sel1_l <= 7'h0;
			ds_scalar_sel2_l <= 7'h0;
			ds_store_value_is_vector <= 1'h0;
			ds_strand <= 2'h0;
			ds_strided_offset <= 32'h0;
			ds_vector_sel1_l <= 7'h0;
			ds_vector_sel2_l <= 7'h0;
			ds_writeback_reg <= 7'h0;
			// End of automatics
		end
		else
		begin
			ds_writeback_reg <= writeback_reg_nxt;
			ds_alu_op <= alu_op_nxt;
			ds_store_value_is_vector <= store_value_is_vector_nxt;
			ds_immediate_value <= immediate_nxt;
			ds_op1_is_vector <= op1_is_vector_nxt;
			ds_op2_src <= op2_src_nxt;
			ds_mask_src <= mask_src_nxt;
			ds_reg_lane_select <= ss_reg_lane_select;
			ds_pc <= ss_pc;	
			ds_strided_offset <= ss_strided_offset;
			ds_vector_sel1_l <= ds_vector_sel1;
			ds_vector_sel2_l <= ds_vector_sel2;
			ds_scalar_sel1_l <= ds_scalar_sel1;
			ds_scalar_sel2_l <= ds_scalar_sel2;
	
			if (squash_ds)
			begin
				ds_instruction 			<= `NOP;
				ds_strand				<= 0;
				ds_branch_predicted		<= 0;
				ds_enable_scalar_writeback	<= 0;
				ds_enable_vector_writeback	<= 0;
				ds_long_latency <= 0;
			end
			else
			begin
				ds_instruction 			<= ss_instruction;
				ds_strand				<= ss_strand;
				ds_branch_predicted		<= ss_branch_predicted;
				ds_enable_scalar_writeback	<= has_writeback && !writeback_is_vector;
				ds_enable_vector_writeback	<= has_writeback && writeback_is_vector;
				ds_long_latency <= ss_long_latency;
			end
		end
	end
endmodule
