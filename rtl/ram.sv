//============================================================================
//  Copyright (C) 2023 Martin Donlon
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

`timescale 1ns / 1ps

module dualport_ram_unreg #(
    parameter WIDTH = 8,
    parameter WIDTHAD = 10
) (
    // Port A
    input   wire                  clock_a,
    input   wire                  wren_a,
    input   wire    [WIDTHAD-1:0] address_a,
    input   wire    [WIDTH-1:0]   data_a,
    output          [WIDTH-1:0]   q_a,

    // Port B
    input   wire                  clock_b,
    input   wire                  wren_b,
    input   wire    [WIDTHAD-1:0] address_b,
    input   wire    [WIDTH-1:0]   data_b,
    output          [WIDTH-1:0]   q_b
);

`ifdef VERILATOR
// Shared ramory
reg [WIDTH-1:0] ram[2**WIDTHAD] /* verilator public_flat */;

// Port A
wire [WIDTH-1:0] q1_a = wren_a ? data_a : ram[address_a];
reg [WIDTH-1:0] q2_a;
assign q_a = q2_a;

always @(posedge clock_a) begin
    if (wren_a) begin
        ram[address_a] <= data_a;
    end
    q2_a <= q1_a;
end

// Port B
wire [WIDTH-1:0] q1_b = wren_b ? data_b : ram[address_b];
reg [WIDTH-1:0] q2_b;
assign q_b = q2_b;

always @(posedge clock_b) begin
    if(wren_b) begin
        ram[address_b] <= data_b;
    end
    q2_b <= q1_b;
end

`else

altsyncram altsyncram_component (
            .address_a (address_a),
            .address_b (address_b),
            .clock0 (clock_a),
            .clock1 (clock_b),
            .data_a (data_a),
            .data_b (data_b),
            .wren_a (wren_a),
            .wren_b (wren_b),
            .q_a (q_a),
            .q_b (q_b),
            .aclr0 (1'b0),
            .aclr1 (1'b0),
            .addressstall_a (1'b0),
            .addressstall_b (1'b0),
            .byteena_a (1'b1),
            .byteena_b (1'b1),
            .clocken0 (1'b1),
            .clocken1 (1'b1),
            .clocken2 (1'b1),
            .clocken3 (1'b1),
            .eccstatus (),
            .rden_a (1'b1),
            .rden_b (1'b1));
defparam
    altsyncram_component.address_reg_b = "CLOCK1",
    altsyncram_component.clock_enable_input_a = "BYPASS",
    altsyncram_component.clock_enable_input_b = "BYPASS",
    altsyncram_component.clock_enable_output_a = "BYPASS",
    altsyncram_component.clock_enable_output_b = "BYPASS",
    altsyncram_component.indata_reg_b = "CLOCK1",
    altsyncram_component.intended_device_family = "Cyclone V",
    altsyncram_component.lpm_type = "altsyncram",
    altsyncram_component.numwords_a = 2**WIDTHAD,
    altsyncram_component.numwords_b = 2**WIDTHAD,
    altsyncram_component.operation_mode = "BIDIR_DUAL_PORT",
    altsyncram_component.outdata_aclr_a = "NONE",
    altsyncram_component.outdata_aclr_b = "NONE",
    altsyncram_component.outdata_reg_a = "UNREGISTERED",
    altsyncram_component.outdata_reg_b = "UNREGISTERED",
    altsyncram_component.power_up_uninitialized = "FALSE",
    altsyncram_component.read_during_write_mode_port_a = "NEW_DATA_NO_NBE_READ",
    altsyncram_component.read_during_write_mode_port_b = "NEW_DATA_NO_NBE_READ",
    altsyncram_component.widthad_a = WIDTHAD,
    altsyncram_component.widthad_b = WIDTHAD,
    altsyncram_component.width_a = WIDTH,
    altsyncram_component.width_b = WIDTH,
    altsyncram_component.width_byteena_a = 1,
    altsyncram_component.width_byteena_b = 1,
    altsyncram_component.wrcontrol_wraddress_reg_b = "CLOCK1";

`endif

endmodule

module singleport_ram #(
    parameter WIDTH = 8,
    parameter WIDTHAD = 10,
    parameter NAME = "NONE"
) (
    input   wire                  clock,
    input   wire                  wren,
    input   wire    [WIDTHAD-1:0] address,
    input   wire    [WIDTH-1:0]   data,
    output  reg     [WIDTH-1:0]   q
);

// Shared ramory
reg [WIDTH-1:0] ram[2**WIDTHAD] /* verilator public_flat */;

always @(posedge clock) begin
    if (wren) begin
        ram[address] <= data;
        q <= data;
    end else begin
        q <= ram[address];
    end
end

endmodule

module singleport_ram_unreg #(
    parameter WIDTH = 8,
    parameter WIDTHAD = 10,
    parameter NAME = "NONE",
    parameter SS_IDX = -1
) (
    input   wire                  clock,
    input   wire                  wren,
    input   wire    [WIDTHAD-1:0] address,
    input   wire    [WIDTH-1:0]   data,
    output          [WIDTH-1:0]   q,

    ssbus_if.slave ssbus
);

// Shared ramory
reg [WIDTH-1:0] ram[2**WIDTHAD] /* verilator public_flat */;

wire [31:0] SIZE = 2**WIDTHAD;

wire [WIDTHAD-1:0] addr = ssbus.access(SS_IDX) ? ssbus.addr[WIDTHAD-1:0] : address;

assign q = ram[addr];
always @(posedge clock) begin
    ssbus.setup(SS_IDX, SIZE, 0);

    if (ssbus.access(SS_IDX)) begin
        if (ssbus.write) begin
            ram[addr] <= ssbus.data[WIDTH-1:0];
            ssbus.write_ack(SS_IDX);
        end else if (ssbus.read) begin
            ssbus.read_response(SS_IDX, { 56'd0, ram[addr] });
        end
    end else begin
        if (wren) begin
            ram[addr] <= data;
        end
    end
end

endmodule

module m68k_ram_unreg #(
    parameter WIDTHAD = 10,
    parameter SS_IDX = -1
) (
    input   wire                  clock,
    input   wire                  we_lds_n,
    input   wire                  we_uds_n,
    input   wire    [WIDTHAD-1:0] address,
    input   wire    [15:0]   data,
    output          [15:0]   q,

    ssbus_if.slave ssbus
);

reg [7:0] ram_l[2**WIDTHAD];
reg [7:0] ram_h[2**WIDTHAD];
wire [31:0] SIZE = 2**WIDTHAD;

wire [WIDTHAD-1:0] addr = ssbus.access(SS_IDX) ? ssbus.addr[WIDTHAD-1:0] : address;

assign q = { ram_h[addr], ram_l[addr] };
always @(posedge clock) begin
    ssbus.setup(SS_IDX, SIZE, 1);

    if (ssbus.access(SS_IDX)) begin
        if (ssbus.write) begin
            ram_l[addr] <= ssbus.data[7:0];
            ram_h[addr] <= ssbus.data[15:8];
            ssbus.write_ack(SS_IDX);
        end else if (ssbus.read) begin
            ssbus.read_response(SS_IDX, { 48'd0, ram_h[addr], ram_l[addr] });
        end
    end else begin
        if (~we_lds_n) ram_l[addr] <= data[7:0];
        if (~we_uds_n) ram_h[addr] <= data[15:8];
    end
end

endmodule

module m68k_ram_reg #(
    parameter WIDTHAD = 10,
    parameter SS_IDX = -1
) (
    input   wire                  clock,
    input   wire                  we_lds_n,
    input   wire                  we_uds_n,
    input   wire    [WIDTHAD-1:0] address,
    input   wire    [15:0]   data,
    output  reg     [15:0]   q,

    ssbus_if.slave ssbus
);

`ifdef VERILATOR

reg [7:0] ram_l[2**WIDTHAD];
reg [7:0] ram_h[2**WIDTHAD];
wire [31:0] SIZE = 2**WIDTHAD;

wire [WIDTHAD-1:0] addr = ssbus.access(SS_IDX) ? ssbus.addr[WIDTHAD-1:0] : address;

always @(posedge clock) begin
    ssbus.setup(SS_IDX, SIZE, 1);

    if (ssbus.access(SS_IDX)) begin
        if (ssbus.write) begin
            ram_l[addr] <= ssbus.data[7:0];
            ram_h[addr] <= ssbus.data[15:8];
            ssbus.write_ack(SS_IDX);
        end else if (ssbus.read) begin
            ssbus.read_response(SS_IDX, { 48'd0, ram_h[addr], ram_l[addr] });
        end
    end else begin
        if (~we_lds_n) begin
            ram_l[addr] <= data[7:0];
            q[7:0] <= data[7:0];
        end else begin
            q[7:0] <= ram_l[addr];
        end

        if (~we_uds_n) begin
            ram_h[addr] <= data[15:8];
            q[15:8] <= data[15:8];
        end else begin
            q[15:8] <= ram_h[addr];
        end
    end
end

`else

wire [WIDTHAD-1:0] addr = ssbus.access(SS_IDX) ? ssbus.addr[WIDTHAD-1:0] : address;
wire [15:0] q_a;
wire [31:0] SIZE = 2**WIDTHAD;

reg read_delay;
always @(posedge clock) begin
    ssbus.setup(SS_IDX, SIZE, 1);

    if (ssbus.access(SS_IDX)) begin
        if (ssbus.write) begin
            ssbus.write_ack(SS_IDX);
        end else if (ssbus.read) begin
            if (read_delay) begin
                ssbus.read_response(SS_IDX, { 48'd0, q_a });
            end
            read_delay <= 1;
        end
    end else begin
        read_delay <= 0;
    end

    q <= q_a;
end


altsyncram altsyncram_component (
            .address_a (addr),
            .clock0 (clock),
            .data_a (ssbus.access(SS_IDX) ? ssbus.data[15:0] : data),
            .wren_a (ssbus.access(SS_IDX) ? ssbus.write : ~(we_uds_n & we_lds_n)),
            .q_a (q_a),
            .aclr0 (1'b0),
            .aclr1 (1'b0),
            .address_b (1'b1),
            .addressstall_a (1'b0),
            .addressstall_b (1'b0),
            .byteena_a (ssbus.access(SS_IDX) ? 2'b11 : { ~we_uds_n, ~we_lds_n }),
            .byteena_b (1'b1),
            .clock1 (1'b1),
            .clocken0 (1'b1),
            .clocken1 (1'b1),
            .clocken2 (1'b1),
            .clocken3 (1'b1),
            .data_b (1'b1),
            .eccstatus (),
            .q_b (),
            .rden_a (1'b1),
            .rden_b (1'b1),
            .wren_b (1'b0));
defparam
    altsyncram_component.clock_enable_input_a = "BYPASS",
    altsyncram_component.clock_enable_output_a = "BYPASS",
    altsyncram_component.intended_device_family = "Cyclone V",
    altsyncram_component.lpm_type = "altsyncram",
    altsyncram_component.numwords_a = 2**WIDTHAD,
    altsyncram_component.operation_mode = "SINGLE_PORT",
    altsyncram_component.outdata_aclr_a = "NONE",
    altsyncram_component.outdata_reg_a = "UNREGISTERED",
    altsyncram_component.power_up_uninitialized = "FALSE",
    altsyncram_component.ram_block_type = "M10K",
    altsyncram_component.read_during_write_mode_port_a = "DONT_CARE",
    altsyncram_component.widthad_a = WIDTHAD,
    altsyncram_component.width_a = 16,
    altsyncram_component.width_byteena_a = 2;


`endif
endmodule


module dualport_ram #(
    parameter WIDTH = 8,
    parameter WIDTHAD = 10
) (
    // Port A
    input   wire                  clock_a,
    input   wire                  wren_a,
    input   wire    [WIDTHAD-1:0] address_a,
    input   wire    [WIDTH-1:0]   data_a,
    output  reg     [WIDTH-1:0]   q_a,

    // Port B
    input   wire                  clock_b,
    input   wire                  wren_b,
    input   wire    [WIDTHAD-1:0] address_b,
    input   wire    [WIDTH-1:0]   data_b,
    output  reg     [WIDTH-1:0]   q_b
);

`ifdef VERILATOR
// Shared ramory
reg [WIDTH-1:0] ram[2**WIDTHAD] /* verilator public_flat */;

// Port A
always @(posedge clock_a) begin
    if (wren_a) begin
        ram[address_a] <= data_a;
        q_a <= data_a;
    end else begin
        q_a <= ram[address_a];
    end
end

// Port B
always @(posedge clock_b) begin
    if(wren_b) begin
        q_b      <= data_b;
        ram[address_b] <= data_b;
    end else begin
        q_b <= ram[address_b];
    end
end

`else

altsyncram altsyncram_component (
            .address_a (address_a),
            .address_b (address_b),
            .clock0 (clock_a),
            .clock1 (clock_b),
            .data_a (data_a),
            .data_b (data_b),
            .wren_a (wren_a),
            .wren_b (wren_b),
            .q_a (q_a),
            .q_b (q_b),
            .aclr0 (1'b0),
            .aclr1 (1'b0),
            .addressstall_a (1'b0),
            .addressstall_b (1'b0),
            .byteena_a (1'b1),
            .byteena_b (1'b1),
            .clocken0 (1'b1),
            .clocken1 (1'b1),
            .clocken2 (1'b1),
            .clocken3 (1'b1),
            .eccstatus (),
            .rden_a (1'b1),
            .rden_b (1'b1));
defparam
    altsyncram_component.address_reg_b = "CLOCK1",
    altsyncram_component.clock_enable_input_a = "BYPASS",
    altsyncram_component.clock_enable_input_b = "BYPASS",
    altsyncram_component.clock_enable_output_a = "BYPASS",
    altsyncram_component.clock_enable_output_b = "BYPASS",
    altsyncram_component.indata_reg_b = "CLOCK1",
    altsyncram_component.intended_device_family = "Cyclone V",
    altsyncram_component.lpm_type = "altsyncram",
    altsyncram_component.numwords_a = 2**WIDTHAD,
    altsyncram_component.numwords_b = 2**WIDTHAD,
    altsyncram_component.operation_mode = "BIDIR_DUAL_PORT",
    altsyncram_component.outdata_aclr_a = "NONE",
    altsyncram_component.outdata_aclr_b = "NONE",
    altsyncram_component.outdata_reg_a = "CLOCK0",
    altsyncram_component.outdata_reg_b = "CLOCK1",
    altsyncram_component.power_up_uninitialized = "FALSE",
    altsyncram_component.read_during_write_mode_port_a = "NEW_DATA_NO_NBE_READ",
    altsyncram_component.read_during_write_mode_port_b = "NEW_DATA_NO_NBE_READ",
    altsyncram_component.widthad_a = WIDTHAD,
    altsyncram_component.widthad_b = WIDTHAD,
    altsyncram_component.width_a = WIDTH,
    altsyncram_component.width_b = WIDTH,
    altsyncram_component.width_byteena_a = 1,
    altsyncram_component.width_byteena_b = 1,
    altsyncram_component.wrcontrol_wraddress_reg_b = "CLOCK1";

`endif
endmodule

`ifdef NOT_SIM
module singleport_ram #(
    parameter width = 8,
    parameter widthad = 10,
    parameter name = "NONE"
) (
    input   wire                   clock,
    input   wire                   wren,
    input   wire    [widthad-1:0]  address,
    input   wire    [width-1:0]    data,
    output  reg     [width-1:0]    q

);

altsyncram    altsyncram_component (
            .address_a (address),
            .clock0 (clock),
            .data_a (data),
            .wren_a (wren),
            .q_a (q),
            .aclr0 (1'b0),
            .aclr1 (1'b0),
            .address_b (1'b1),
            .addressstall_a (1'b0),
            .addressstall_b (1'b0),
            .byteena_a (1'b1),
            .byteena_b (1'b1),
            .clock1 (1'b1),
            .clocken0 (1'b1),
            .clocken1 (1'b1),
            .clocken2 (1'b1),
            .clocken3 (1'b1),
            .data_b (1'b1),
            .eccstatus (),
            .q_b (),
            .rden_a (1'b1),
            .rden_b (1'b1),
            .wren_b (1'b0));
defparam
    altsyncram_component.clock_enable_input_a = "BYPASS",
    altsyncram_component.clock_enable_output_a = "BYPASS",
    altsyncram_component.intended_device_family = "Cyclone V",
    altsyncram_component.lpm_hint = {"ENABLE_RUNTIME_MOD=YES,INSTANCE_NAME=", name},
    altsyncram_component.lpm_type = "altsyncram",
    altsyncram_component.numwords_a = 2**widthad,
    altsyncram_component.operation_mode = "SINGLE_PORT",
    altsyncram_component.outdata_aclr_a = "NONE",
    altsyncram_component.outdata_reg_a = "CLOCK0",
    altsyncram_component.power_up_uninitialized = "FALSE",
    altsyncram_component.ram_block_type = "M10K",
    altsyncram_component.read_during_write_mode_port_a = "DONT_CARE",
    altsyncram_component.widthad_a = widthad,
    altsyncram_component.width_a = width,
    altsyncram_component.width_byteena_a = 1;


endmodule

module singleport_unreg_ram #(
    parameter width = 8,
    parameter widthad = 10,
) (
    input   wire                   clock,
    input   wire                   wren,
    input   wire    [widthad-1:0]  address,
    input   wire    [width-1:0]    data,
    output  wire    [width-1:0]    q
);

altsyncram    altsyncram_component (
            .address_a (address),
            .clock0 (clock),
            .data_a (data),
            .wren_a (wren),
            .q_a (q),
            .aclr0 (1'b0),
            .aclr1 (1'b0),
            .address_b (1'b1),
            .addressstall_a (1'b0),
            .addressstall_b (1'b0),
            .byteena_a (1'b1),
            .byteena_b (1'b1),
            .clock1 (1'b1),
            .clocken0 (1'b1),
            .clocken1 (1'b1),
            .clocken2 (1'b1),
            .clocken3 (1'b1),
            .data_b (1'b1),
            .eccstatus (),
            .q_b (),
            .rden_a (1'b1),
            .rden_b (1'b1),
            .wren_b (1'b0));
defparam
    altsyncram_component.clock_enable_input_a = "BYPASS",
    altsyncram_component.clock_enable_output_a = "BYPASS",
    altsyncram_component.intended_device_family = "Cyclone V",
    altsyncram_component.lpm_type = "altsyncram",
    altsyncram_component.numwords_a = 2**widthad,
    altsyncram_component.operation_mode = "SINGLE_PORT",
    altsyncram_component.outdata_aclr_a = "NONE",
    altsyncram_component.outdata_reg_a = "UNREGISTERED",
    altsyncram_component.power_up_uninitialized = "FALSE",
    altsyncram_component.ram_block_type = "M10K",
    altsyncram_component.read_during_write_mode_port_a = "DONT_CARE",
    altsyncram_component.widthad_a = widthad,
    altsyncram_component.width_a = width,
    altsyncram_component.width_byteena_a = 1;

endmodule
`endif

