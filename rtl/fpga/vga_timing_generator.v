// 
// Copyright 2012 Jeff Bush
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

module vga_timing_generator(
	input clk, 
	output reg vga_vs = 0, 
	output reg vga_hs = 0, 
	output vga_blank_n,
	output reg[10:0] horizontal_counter = 0,
	output reg[10:0] vertical_counter = 0,
	output reg vga_sync_n);

	// 640x480 @60 hz.  Pixel clock = 25.175 Mhz Vert Refresh = 31.46875 kHz
	// Horizontal timing:
	// front porch 16 clocks
	// sync pulse 96 clocks
	// back porch 48 clocks
	// visible area 640 clocks
	// total 800 clocks
	//
	// Vertical timing:
	// front porch 10 lines
	// sync pulse 2 lines
	// back porch 33 lines
	// visible area 480 lines
	// total 525 lines
	parameter HSYNC_START = 16;						// Front Porch
	parameter HSYNC_END = HSYNC_START + 96;
	parameter HVISIBLE_START = HSYNC_END + 48;		// Back Porch
	parameter HVISIBLE_END = HVISIBLE_START + 640;
	parameter VSYNC_START = 10;						// Front Porch
	parameter VSYNC_END = VSYNC_START + 2;
	parameter VVISIBLE_START = VSYNC_END + 33;		// Back Porch
	parameter VVISIBLE_END = VVISIBLE_START + 480;
	
	reg hvisible = 0;
	reg vvisible = 0;
	
	assign vga_blank_n = hvisible && vvisible;
	
	initial
	begin
		vga_sync_n = 1;	// Quartus ignores initializers in port lists sometimes
	end

	wire hvisible_end = horizontal_counter == HVISIBLE_END;
	wire vvisible_end = vertical_counter == VVISIBLE_END;

	always @(posedge clk)
	begin
		vga_sync_n <= ~(hvisible_end && vvisible_end);
	
		// Counters
		if (hvisible_end)
		begin
			horizontal_counter <= 0;
			hvisible <= 0;
			if (vvisible_end)
			begin
				vvisible <= 0;
				vertical_counter <= 0;
			end
			else 
				vertical_counter <= vertical_counter + 1;
		end
		else
			horizontal_counter <= horizontal_counter + 1;

		if (vertical_counter == VSYNC_START)
			vga_vs <= 0;
		else if (vertical_counter == VSYNC_END)
			vga_vs <= 1;
		else if (vertical_counter == VVISIBLE_START)
			vvisible <= 1;

		if (horizontal_counter == HSYNC_START)
			vga_hs <= 0;
		else if (horizontal_counter == HSYNC_END)
			vga_hs <= 1;
		else if (horizontal_counter == HVISIBLE_START)
			hvisible <= 1;
	end
endmodule

