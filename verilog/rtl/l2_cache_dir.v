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

`include "l2_cache.h"

//
// L2 cache pipeline directory stage.
// - If this is a cache hit, update L2 cache directory to reflect line that will
// be pushed to L1 cache.
// - On a store, check if any L1 lines map the data and need to be updated.
// - Update/check dirty bits
//

module l2_cache_dir(
	input                            clk,
	input                            stall_pipeline,
	input                            tag_l2req_valid,
	input[1:0]                       tag_l2req_core,
	input[1:0]                       tag_l2req_unit,
	input[1:0]                       tag_l2req_strand,
	input[2:0]                       tag_l2req_op,
	input[1:0]                       tag_l2req_way,
	input[25:0]                      tag_l2req_address,
	input[511:0]                     tag_l2req_data,
	input[63:0]                      tag_l2req_mask,
	input                            tag_has_sm_data,
	input[511:0]                     tag_sm_data,
	input[1:0]                       tag_sm_fill_l2_way,
	input[1:0]                       tag_replace_l2_way,
	input[`L2_TAG_WIDTH - 1:0]       tag_l2_tag0,
	input[`L2_TAG_WIDTH - 1:0]       tag_l2_tag1,
	input[`L2_TAG_WIDTH - 1:0]       tag_l2_tag2,
	input[`L2_TAG_WIDTH - 1:0]       tag_l2_tag3,
	input                            tag_l2_valid0,
	input                            tag_l2_valid1,
	input                            tag_l2_valid2,
	input                            tag_l2_valid3,
	output reg                       dir_l2req_valid = 0,
	output reg[1:0]                  dir_l2req_core = 0,
	output reg[1:0]                  dir_l2req_unit = 0,
	output reg[1:0]                  dir_l2req_strand = 0,
	output reg[2:0]                  dir_l2req_op = 0,
	output reg[1:0]                  dir_l2req_way = 0,
	output reg[25:0]                 dir_l2req_address = 0,
	output reg[511:0]                dir_l2req_data = 0,
	output reg[63:0]                 dir_l2req_mask = 0,
	output reg                       dir_has_sm_data = 0,
	output reg[511:0]                dir_sm_data = 0,
	output reg[1:0]                  dir_sm_fill_way = 0,
	output reg[1:0]                  dir_hit_l2_way = 0,
	output reg[1:0]                  dir_replace_l2_way = 0,
	output reg                       dir_cache_hit = 0,
	output reg[`L2_TAG_WIDTH - 1:0]  dir_old_l2_tag = 0,
	output                           dir_l1_has_line_core0,
	output [`NUM_CORES * 2 - 1:0]    dir_l1_way_core0,
	output                           dir_l1_has_line_core1,
	output [`NUM_CORES * 2 - 1:0]    dir_l1_way_core1,
	output                           dir_l2_dirty0,
	output                           dir_l2_dirty1,
	output                           dir_l2_dirty2,
	output                           dir_l2_dirty3);

	wire[`L1_TAG_WIDTH - 1:0] requested_l1_tag = tag_l2req_address[25:`L1_SET_INDEX_WIDTH];
	wire[`L1_SET_INDEX_WIDTH - 1:0] requested_l1_set = tag_l2req_address[`L1_SET_INDEX_WIDTH - 1:0];
	wire[`L2_TAG_WIDTH - 1:0] requested_l2_tag = tag_l2req_address[25:`L2_SET_INDEX_WIDTH];
	wire[`L2_SET_INDEX_WIDTH - 1:0] requested_l2_set = tag_l2req_address[`L2_SET_INDEX_WIDTH - 1:0];

	wire is_store = tag_l2req_op == `L2REQ_STORE || tag_l2req_op == `L2REQ_STORE_SYNC;
	wire is_flush = tag_l2req_op == `L2REQ_FLUSH;

	wire update_directory = !stall_pipeline
		&& tag_l2req_valid
		&& (tag_l2req_op == `L2REQ_LOAD || tag_l2req_op == `L2REQ_LOAD_SYNC) 
		&& (cache_hit || tag_has_sm_data)
		&& tag_l2req_unit == `UNIT_DCACHE;
	wire update_directory_core0 = update_directory /* And core 0... */;
	wire update_directory_core1 = update_directory /* And core 1... */;
	
	// The directory is basically a clone of the tag memories for all core's L1 data
	// caches.
	l1_cache_tag directory_core0(
		.clk(clk),
		.address_i({ tag_l2req_address, 6'd0 }),
		.access_i(tag_l2req_valid),
		.cache_hit_o(dir_l1_has_line_core0),
		.hit_way_o(dir_l1_way_core0),
		.invalidate_i(0),
		.update_i(update_directory_core0),
		.update_way_i(tag_l2req_way),
		.update_tag_i(requested_l1_tag),
		.update_set_i(requested_l1_set));

	l1_cache_tag directory_core1(
		.clk(clk),
		.address_i({ tag_l2req_address, 6'd0 }),
		.access_i(tag_l2req_valid),
		.cache_hit_o(dir_l1_has_line_core1),
		.hit_way_o(dir_l1_way_core1),
		.invalidate_i(0),
		.update_i(update_directory_core1),
		.update_way_i(tag_l2req_way),
		.update_tag_i(requested_l1_tag),
		.update_set_i(requested_l1_set));

	wire l2_hit0 = tag_l2_tag0 == requested_l2_tag && tag_l2_valid0;
	wire l2_hit1 = tag_l2_tag1 == requested_l2_tag && tag_l2_valid1;
	wire l2_hit2 = tag_l2_tag2 == requested_l2_tag && tag_l2_valid2;
	wire l2_hit3 = tag_l2_tag3 == requested_l2_tag && tag_l2_valid3;
	wire cache_hit = l2_hit0 || l2_hit1 || l2_hit2 || l2_hit3;
	wire[1:0] hit_l2_way = { l2_hit2 | l2_hit3, l2_hit1 | l2_hit3 }; // convert one-hot to index

	assertion #("l2_cache_dir: more than one way was a hit") a(.clk(clk), 
		.test(l2_hit0 + l2_hit1 + l2_hit2 + l2_hit3 > 1));

	reg[`L2_TAG_WIDTH - 1:0] old_l2_tag_muxed = 0;

	always @*
	begin
		case (tag_has_sm_data ? tag_sm_fill_l2_way : hit_l2_way)
			0: old_l2_tag_muxed = tag_l2_tag0;
			1: old_l2_tag_muxed = tag_l2_tag1;
			2: old_l2_tag_muxed = tag_l2_tag2;
			3: old_l2_tag_muxed = tag_l2_tag3;
		endcase
	end


	reg dir_l2_valid0 = 0;
	reg dir_l2_valid1 = 0;
	reg dir_l2_valid2 = 0;
	reg dir_l2_valid3 = 0;

	wire update_dirty = !stall_pipeline && tag_l2req_valid &&
		(tag_has_sm_data || (cache_hit && (is_store || is_flush)));
	wire update_dirty0 = update_dirty && (tag_has_sm_data 
		? tag_sm_fill_l2_way == 0 : l2_hit0);
	wire update_dirty1 = update_dirty && (tag_has_sm_data 
		? tag_sm_fill_l2_way == 1 : l2_hit1);
	wire update_dirty2 = update_dirty && (tag_has_sm_data 
		? tag_sm_fill_l2_way == 2 : l2_hit2);
	wire update_dirty3 = update_dirty && (tag_has_sm_data 
		? tag_sm_fill_l2_way == 3 : l2_hit3);

	reg new_dirty = 0;

	always @*
	begin
		if (tag_has_sm_data)
			new_dirty = is_store; // Line fill, mark dirty if a store is occurring.
		else if (is_flush)
			new_dirty = 1'b0; // Clear dirty bit
		else
			new_dirty = 1'b1; // Store, cache hit.  Set dirty.
	end

	wire dirty0;
	wire dirty1;
	wire dirty2;
	wire dirty3;

	sram_1r1w #(1, `L2_NUM_SETS, `L2_SET_INDEX_WIDTH, 1) l2_dirty_mem0(
		.clk(clk),
		.rd_addr(requested_l2_set),
		.rd_data(dirty0),
		.wr_addr(requested_l2_set),
		.wr_data(new_dirty),
		.wr_enable(update_dirty0));

	sram_1r1w #(1, `L2_NUM_SETS, `L2_SET_INDEX_WIDTH, 1) l2_dirty_mem1(
		.clk(clk),
		.rd_addr(requested_l2_set),
		.rd_data(dirty1),
		.wr_addr(requested_l2_set),
		.wr_data(new_dirty),
		.wr_enable(update_dirty1));

	sram_1r1w #(1, `L2_NUM_SETS, `L2_SET_INDEX_WIDTH, 1) l2_dirty_mem2(
		.clk(clk),
		.rd_addr(requested_l2_set),
		.rd_data(dirty2),
		.wr_addr(requested_l2_set),
		.wr_data(new_dirty),
		.wr_enable(update_dirty2));

	sram_1r1w #(1, `L2_NUM_SETS, `L2_SET_INDEX_WIDTH, 1) l2_dirty_mem3(
		.clk(clk),
		.rd_addr(requested_l2_set),
		.rd_data(dirty3),
		.wr_addr(requested_l2_set),
		.wr_data(new_dirty),
		.wr_enable(update_dirty3));

	assign dir_l2_dirty0 = dirty0 && dir_l2_valid0;
	assign dir_l2_dirty1 = dirty1 && dir_l2_valid1;
	assign dir_l2_dirty2 = dirty2 && dir_l2_valid2;
	assign dir_l2_dirty3 = dirty3 && dir_l2_valid3;

	always @(posedge clk)
	begin
		if (!stall_pipeline)
		begin
			dir_l2req_valid <= #1 tag_l2req_valid;
			dir_l2req_core <= #1 tag_l2req_core;
			dir_l2req_unit <= #1 tag_l2req_unit;
			dir_l2req_strand <= #1 tag_l2req_strand;
			dir_l2req_op <= #1 tag_l2req_op;
			dir_l2req_way <= #1 tag_l2req_way;
			dir_l2req_address <= #1 tag_l2req_address;
			dir_l2req_data <= #1 tag_l2req_data;
			dir_l2req_mask <= #1 tag_l2req_mask;
			dir_has_sm_data <= #1 tag_has_sm_data;	
			dir_sm_data <= #1 tag_sm_data;		
			dir_hit_l2_way <= #1 hit_l2_way;
			dir_replace_l2_way <= #1 tag_replace_l2_way;
			dir_cache_hit <= #1 cache_hit;
			dir_old_l2_tag <= #1 old_l2_tag_muxed;
			dir_sm_fill_way <= #1 tag_sm_fill_l2_way;
			dir_l2_valid0 <= tag_l2_valid0;
			dir_l2_valid1 <= tag_l2_valid1;
			dir_l2_valid2 <= tag_l2_valid2;
			dir_l2_valid3 <= tag_l2_valid3;
		end
	end
endmodule
