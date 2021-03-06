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
// L2 cache interface constants
//

`define L2REQ_LOAD  3'b000
`define L2REQ_STORE 3'b001
`define L2REQ_FLUSH 3'b010
`define L2REQ_DINVALIDATE 3'b011
`define L2REQ_LOAD_SYNC 3'b100
`define L2REQ_STORE_SYNC 3'b101
`define L2REQ_IINVALIDATE 3'b110

`define L2RSP_LOAD_ACK 2'b00
`define L2RSP_STORE_ACK 2'b01
`define L2RSP_DINVALIDATE 2'b10
`define L2RSP_IINVALIDATE 2'b11

// The L2 cache directory mirrors the configuration of the L1 caches to
// maintain coherence, so these are defined globally instead of with
// parameters
//
// L1 caches are 8k. There are 4 ways, 32 sets, 64 bytes per line
//	   bits 0-5 (6) of address are the offset into the line
//	   bits 6-10 (5) are the set index
//	   bits 11-31 (21) are the tag
//
// NOTE: a lot of address indices are hard coded into sub modules.  Changing
// these would probably break modules if those are not adjusted or parameterized.
//
`define L1_NUM_SETS 32
`define L1_NUM_WAYS 4
`define L1_SET_INDEX_WIDTH 5	// log2 L1_NUM_SETS
`define L1_WAY_INDEX_WIDTH 2	// log2 L1_NUM_WAYS
`define L1_TAG_WIDTH 21 		// 32 - L1_SET_INDEX_WIDTH - 6

//
// L2 cache is 64k.  There are 4 ways, 256 sets, 64 bytes per line.
//	   bits 0-5 (6) of address are the offset into the line
//	   bits 6-13 (8) are the set index
//	   bits 14-31 (18) are the tag
//
`define L2_NUM_SETS 256
`define L2_NUM_WAYS 4
`define L2_SET_INDEX_WIDTH 8
`define L2_WAY_INDEX_WIDTH 2
`define L2_TAG_WIDTH 18 		// 32 - L1_SET_INDEX_WIDTH - 6
`define L2_CACHE_ADDR_WIDTH 10 	// L2_SET_INDEX_WIDTH + L2_WAY_INDEX_WIDTH

`define NUM_CORES 1
`define STRANDS_PER_CORE 4

// l2req_unit identifiers
`define UNIT_ICACHE 2'd0
`define UNIT_DCACHE 2'd1
`define UNIT_STBUF 2'd2

