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
// The integer multiplier has 3 cycles of latency.
// This is a stub for now.  It is intended to be replaced by something
// like a wallace tree.
//

module integer_multiplier(
	input	 					clk,
	input						reset,
	input [31:0]				multiplicand,
	input [31:0]				multiplier,
	output reg[47:0]			mult_product);
	
	reg[47:0]					product1;
	reg[47:0]					product2;

	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			mult_product <= 48'h0;
			product1 <= 48'h0;
			product2 <= 48'h0;
			// End of automatics
		end
		else
		begin
			product1 <= multiplicand * multiplier;
			product2 <= product1;
			mult_product <= product2;
		end
	end
endmodule
