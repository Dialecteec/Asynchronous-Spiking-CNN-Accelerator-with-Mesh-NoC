`timescale 1ns/1ps

`include "adder_gate.sv"

module adder #(
    parameter WIDTH = 10,
    parameter FL    = 6,
    parameter COMB_DELAY = 1,
    parameter CTRL_DELAY = 1
)(
    input  logic             rst,
    input  logic             lreq1,
    output logic             lack1,
    input  logic [WIDTH-1:0] ldata1,

    input  logic             lreq2,
    output logic             lack2,
    input  logic [WIDTH-1:0] ldata2,

    output logic             rreq,
    input  logic             rack,
    output logic [WIDTH-1:0] rdata
);

    logic lreq_merged, lack_merged, delayed_lreq_merged;
    logic [WIDTH:0] sum, sum_gate;

    assign lreq_merged = lreq1 & lreq2;

    AsymmDelayLine #(
        .DELAY(COMB_DELAY)
    ) delayLine (
        .in(lreq_merged),
        .out(delayed_lreq_merged)
    );

    adder_gate #(
        .WIDTH(WIDTH)
    ) U_adder_gate (
        .opA(ldata1),
        .opB(ldata2),
        .sum(sum_gate)
    );

    assign #(FL) sum = sum_gate;

    FDController #(
        .WIDTH(WIDTH+1),
        .DELAY(CTRL_DELAY)
    ) cc (
        .rst  (rst),
        .lreq (delayed_lreq_merged),
        .lack (lack_merged),
        .ldata(sum),
        .rreq (rreq),
        .rack (rack),
        .rdata(rdata)
    );

    assign lack1 = lack_merged;
    assign lack2 = lack_merged;

endmodule
