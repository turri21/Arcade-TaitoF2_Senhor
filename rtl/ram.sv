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

module dualport_ram #(
    parameter WIDTH = 8,
    parameter WIDTHAD = 10,
    parameter NAME = "NONE"
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

endmodule

module dualport_ram_unreg #(
    parameter WIDTH = 8,
    parameter WIDTHAD = 10,
    parameter NAME = "NONE"
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

// Shared ramory
reg [WIDTH-1:0] ram[2**WIDTHAD] /* verilator public_flat */;

// Port A
assign q_a = ram[address_a];

always @(posedge clock_a) begin
    if (wren_a) begin
        ram[address_a] <= data_a;
    end
end

// Port B
assign q_b = ram[address_b];

always @(posedge clock_b) begin
    if(wren_b) begin
        q_b      <= data_b;
        ram[address_b] <= data_b;
    end
end

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

interface ss2device_if #(parameter COUNT = 8)(
    input [63:0] data,
    input [23:0] addr,
    input [COUNT-1:0] select,
    input write,
    input read,
    input query,
    output reg [63:0] data_out[COUNT],
    output reg [COUNT-1:0] ack

);
    function logic access(int idx);
        return select[idx] & ~query & (read | write);
    endfunction

    task setup(int idx, input [31:0] count, input [1:0] width);
        ack[idx] <= 0;
        if (select[idx] & query) begin
            data_out[idx] <= { idx[7:0], 22'b0, width, count };
            ack[idx] <= 1;
        end
    endtask

    task read_response(int idx, input [63:0] dout);
        data_out[idx] <= dout;
        ack[idx] <= 1;
    endtask

    task write_ack(int idx);
        ack[idx] <= 1;
    endtask

endinterface

module singleport_ram_unreg #(
    parameter WIDTH = 8,
    parameter WIDTHAD = 10,
    parameter NAME = "NONE",
    parameter SS_IDX = 0
) (
    input   wire                  clock,
    input   wire                  wren,
    input   wire    [WIDTHAD-1:0] address,
    input   wire    [WIDTH-1:0]   data,
    output          [WIDTH-1:0]   q,

    ss2device_if ssd
);

// Shared ramory
reg [WIDTH-1:0] ram[2**WIDTHAD] /* verilator public_flat */;

wire [31:0] SIZE = 2**WIDTHAD;

wire [WIDTHAD-1:0] addr = ssd.access(SS_IDX) ? ssd.addr[WIDTHAD-1:0] : address;

assign q = ram[addr];
always @(posedge clock) begin
    ssd.setup(SS_IDX, SIZE, 0);

    if (ssd.access(SS_IDX)) begin
        if (ssd.write) begin
            ram[addr] <= ssd.data[WIDTH-1:0];
            ssd.write_ack(SS_IDX);
        end else if (ssd.read) begin
            ssd.read_response(SS_IDX, { 56'd0, ram[addr] });
        end
    end else begin
        if (wren) begin
            ram[addr] <= data;
        end
    end
end

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

altsyncram	altsyncram_component (
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
    parameter name = "NONE"
) (
    input   wire                   clock,
    input   wire                   wren,
    input   wire    [widthad-1:0]  address,
    input   wire    [width-1:0]    data,
    output  wire    [width-1:0]    q
);

altsyncram	altsyncram_component (
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
    altsyncram_component.outdata_reg_a = "UNREGISTERED",
    altsyncram_component.power_up_uninitialized = "FALSE",
    altsyncram_component.ram_block_type = "M10K",
    altsyncram_component.read_during_write_mode_port_a = "DONT_CARE",
    altsyncram_component.widthad_a = widthad,
    altsyncram_component.width_a = width,
    altsyncram_component.width_byteena_a = 1;

endmodule
`endif

