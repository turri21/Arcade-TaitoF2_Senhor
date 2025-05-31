/*  This file is part of JT12.

    JT12 is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT12 is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT12.  If not, see <http://www.gnu.org/licenses/>.

	Author: Jose Tejada Gomez. Twitter: @topapate
	Version: 1.0
	Date: 1-31-2017
	*/


// stages must be greater than 2
module jt12_sh #(parameter width=5, stages=24 )
(
`ifdef USE_AUTO_SS
	input  [stages*width - 1:0] auto_ss_in,
	input					    auto_ss_wr,
	output [stages*width - 1:0] auto_ss_out,
`endif // USE_AUTO_SS

	input 				clk,
	input				clk_en /* synthesis direct_enable */,
	input	[width-1:0]	din,
   	output	[width-1:0]	drop
);

reg [stages-1:0] bits[width-1:0];

genvar i;
generate
	for (i=0; i < width; i=i+1) begin: bit_shifter
		always @(posedge clk) begin
			if(clk_en) begin
				bits[i] <= {bits[i][stages-2:0], din[i]};
			end

`ifdef USE_AUTO_SS
			if (auto_ss_wr) begin
				bits[i] <= auto_ss_in[i*stages+:stages];
			end
`endif
		end
		assign drop[i] = bits[i][stages-1];

`ifdef USE_AUTO_SS
		assign auto_ss_out[i*stages+:stages] = bits[i];
`endif
	end
endgenerate

endmodule
