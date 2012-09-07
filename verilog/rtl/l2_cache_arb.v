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
// L2 cache pipeline arbitration stage
// Determines whether a request from a core or a restarted request from
// the system memory interface queue should be pushed down the pipeline.
// The latter always has priority.
//

module l2_cache_arb(
	input						clk,
	input						stall_pipeline,
	input						l2req_valid,
	output reg					l2req_ack,
	input [1:0]					l2req_core,
	input [1:0]					l2req_unit,
	input [1:0]					l2req_strand,
	input [2:0]					l2req_op,
	input [1:0]					l2req_way,
	input [25:0]				l2req_address,
	input [511:0]				l2req_data,
	input [63:0]				l2req_mask,
	input [1:0]					smi_l2req_core,				
	input [1:0]					smi_l2req_unit,				
	input [1:0]					smi_l2req_strand,
	input [2:0]					smi_l2req_op,
	input [1:0]					smi_l2req_way,
	input [25:0]				smi_l2req_address,
	input [511:0]				smi_l2req_data,
	input [63:0]				smi_l2req_mask,
	input [511:0] 				smi_load_buffer_vec,
	input						smi_data_ready,
	input [1:0]					smi_fill_l2_way,
	input						smi_duplicate_request,
	output reg					arb_l2req_valid = 0,
	output reg[1:0]				arb_l2req_core = 0,
	output reg[1:0]				arb_l2req_unit = 0,
	output reg[1:0]				arb_l2req_strand = 0,
	output reg[2:0]				arb_l2req_op = 0,
	output reg[1:0]				arb_l2req_way = 0,
	output reg[25:0]			arb_l2req_address = 0,
	output reg[511:0]			arb_l2req_data = 0,
	output reg[63:0]			arb_l2req_mask = 0,
	output reg					arb_has_sm_data = 0,
	output reg[511:0]			arb_sm_data = 0,
	output reg[1:0]				arb_sm_fill_l2_way = 0);


	always @(posedge clk)
	begin
		if (!stall_pipeline)
		begin
			if (smi_data_ready)	
			begin
				l2req_ack <= #1 0;
				arb_l2req_valid <= #1 1'b1;
				arb_l2req_core <= #1 smi_l2req_core;
				arb_l2req_unit <= #1 smi_l2req_unit;
				arb_l2req_strand <= #1 smi_l2req_strand;
				arb_l2req_op <= #1 smi_l2req_op;
				arb_l2req_way <= #1 smi_l2req_way;
				arb_l2req_address <= #1 smi_l2req_address;
				arb_l2req_data <= #1 smi_l2req_data;
				arb_l2req_mask <= #1 smi_l2req_mask;
				arb_has_sm_data <= #1 !smi_duplicate_request;
				arb_sm_data <= #1 smi_load_buffer_vec;
				arb_sm_fill_l2_way <= #1 smi_fill_l2_way;
			end
			else
			begin
				l2req_ack <= #1 l2req_valid;	
				arb_l2req_valid <= #1 l2req_valid;
				arb_l2req_core <= #1 l2req_core;
				arb_l2req_unit <= #1 l2req_unit;
				arb_l2req_strand <= #1 l2req_strand;
				arb_l2req_op <= #1 l2req_op;
				arb_l2req_way <= #1 l2req_way;
				arb_l2req_address <= #1 l2req_address;
				arb_l2req_data <= #1 l2req_data;
				arb_l2req_mask <= #1 l2req_mask;
				arb_has_sm_data <= #1 0;
				arb_sm_data <= #1 0;
			end
		end
		else
			l2req_ack <= #1 0;
	end
endmodule
