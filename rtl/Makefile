# 
# Copyright 2011-2012 Jeff Bush
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# 


SIMULATOR_SRCS=	core/instruction_fetch_stage.v \
			core/strand_select_stage.v \
			core/decode_stage.v \
			core/execute_stage.v \
			core/memory_access_stage.v \
			core/writeback_stage.v \
			core/pipeline.v \
			core/vector_register_file.v \
			core/scalar_register_file.v \
			core/vector_bypass_unit.v \
			core/rollback_controller.v \
			core/multi_cycle_vector_alu.v \
			core/multi_cycle_scalar_alu.v \
			core/single_cycle_vector_alu.v \
			core/single_cycle_scalar_alu.v \
			core/fp_adder_stage1.v \
			core/fp_adder_stage2.v \
			core/fp_adder_stage3.v \
			core/fp_multiplier_stage1.v \
			core/fp_normalize.v \
			core/integer_multiplier.v \
			core/lane_select_mux.v \
			core/vector_shuffler.v \
			core/fp_reciprocal_estimate.v \
			core/reciprocal_rom.v \
			core/l1_cache.v \
			core/l1_cache_tag.v \
			core/cache_lru.v \
			core/store_buffer.v \
			core/sync_fifo.v \
			core/arbiter.v \
			core/strand_fsm.v \
			core/core.v \
			core/load_miss_queue.v \
			core/mask_unit.v \
			core/l2req_arbiter_mux.v \
			core/execute_hazard_detect.v \
			core/assert_false.v \
			core/control_registers.v \
			core/l2_cache.v \
			core/l2_cache_arb.v \
			core/l2_cache_response.v \
			core/l2_cache_bus_interface.v \
			core/l2_cache_tag.v \
			core/l2_cache_dir.v \
			core/l2_cache_read.v \
			core/l2_cache_write.v \
			core/l2_cache_pending_miss.v \
			core/sram_1r1w.v \
			core/axi_sram.v \
			testbench/simulator_top.v 
			
HEADERS=core/decode.h \
	core/instruction_format.h \
	core/l2_cache.h

IVFLAGS=-Wall -Winfloop -civerilog.cmd -Wno-sensitivity-entire-array -Icore

sim.vvp: $(SIMULATOR_SRCS) $(HEADERS) Makefile
	iverilog -o $@ $(IVFLAGS) $(SIMULATOR_SRCS)

# Expands AUTOWIRE/AUTOINST/etc. Requires emacs and verilog-mode module installed.
autos: $(SIMULATOR_SRCS)
	emacs --batch $(SIMULATOR_SRCS) -f verilog-batch-auto -f save-buffer
	emacs --batch fpga/* -f verilog-batch-auto -f save-buffer

lint: $(SIMULATOR_SRCS)
	-verilator --lint-only core/core.v -Wall -Icore -Wno-ASSIGNDLY 
	-verilator --lint-only core/l2_cache.v -Wall -Icore -Wno-ASSIGNDLY 

clean:
	rm -f sim.vvp
