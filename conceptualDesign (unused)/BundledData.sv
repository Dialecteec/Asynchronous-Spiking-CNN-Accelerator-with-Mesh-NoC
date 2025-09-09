`timescale 1ns/1ps
import SystemVerilogCSP::*;

// Combinational blocks
    // gate-level full adder
    module full_adder (
        input   x,  // Input x
        input   y,  // Input y
        input   ci, // Carry-in
        output  s,  // Sum output
        output  co  // Carry-out
    );

        // Using gate-level descriptions
        // s = x ^ y ^ ci
        // co = (x & y) | (x & ci) | (y & ci)
        wire x_xor_y;
        wire x_and_y;
        wire x_and_ci;
        wire y_and_ci;

        xor (x_xor_y, x, y);
        xor (s, x_xor_y, ci);
        and (x_and_y,  x,  y);
        and (x_and_ci, x,  ci);
        and (y_and_ci, y,  ci);
        or  (co, x_and_y, x_and_ci, y_and_ci);

    endmodule

    // adder array
    module adder_gate #(parameter WIDTH=8)(input [WIDTH-1:0] opA,opB,
                                        output [WIDTH:0]  sum);
        logic [WIDTH-1:0] carry;
        genvar i;
        generate
            for(i=0;i<WIDTH;i++) begin: chain
                full_adder FA(.x(opA[i]), .y(opB[i]),
                            .ci(i==0?1'b0:carry[i-1]),
                            .s(sum[i]), .co(carry[i]));
            end
        endgenerate
        assign sum[WIDTH] = carry[WIDTH-1];
    endmodule

    // subtractor array built from adder_gate (+2’s‑complement)
    module sub_gate  #(parameter WIDTH=8)(
        input  [WIDTH-1:0] opA, opB,
        output [WIDTH  :0] diff
    );
        logic [WIDTH:0] tmp;
        adder_gate #(.WIDTH(WIDTH)) ADD(.opA(opA), .opB(~opB), .sum(tmp));
        assign diff = tmp + 1'b1;     // +1 for two’s‑comp
    endmodule

// Delay line
    module AsymmDelayLine #(
    parameter real DELAY = 1.0
    )(
    input  logic in,
    output logic out
    );

    logic inv_out, nor1_out, nor2_out, nor3_out, nor4_out, dly;

    assign inv_out  = ~in;

    assign nor1_out = ~(inv_out | nor2_out);

    assign #DELAY dly = nor1_out;

    assign nor3_out = ~(dly      | nor2_out);
    assign nor4_out = ~(dly      | nor3_out);
    assign nor2_out = ~(nor3_out | inv_out);

    assign out      = nor4_out;

    endmodule

// Bundled-data controller
    module FDController #(
    parameter WIDTH = 8,
    parameter DELAY = 1
    )(
    input  logic             rst,
    input  logic             lreq,
    input  logic             rack,
    input  logic [WIDTH-1:0] ldata,

    output logic             lack = 0,
    output logic             rreq = 0,
    output logic [WIDTH-1:0] rdata
    );

    logic a, b, a_delayed;

    assign #(DELAY) a_delayed = a;

    always_comb begin
        b = rst ? 0 : (lack | (b & a_delayed));
        lack = rst ? 0 : ((~b & a_delayed) | (lack & (~b | lreq)));
        a = rst ? 0 : ((~b & ~rreq & lreq) | (a & ((~b | ~rreq) | ~rack)));
        rreq = rst ? 0 : ((a & ~rack) | (rreq & a));
    end

    always_latch begin
        if (rst)
        rdata = 0;
        else if (a_delayed)
        rdata = ldata;
    end
    endmodule

// Bundled-data cell
    module BD_cell #(
        parameter WIDTH        = 8,
        parameter COMB         = "ADD",   // "ADD" or "SUB"
        parameter FL           = 0,
        parameter COMB_DELAY   = 0,
        parameter CTRL_DELAY   = 0
    )(
        input  logic rst,
        // BD input side
        input  logic             lreq1,  output logic lack1,
        input  logic [WIDTH-1:0] ldata1,
        input  logic             lreq2,  output logic lack2,
        input  logic [WIDTH-1:0] ldata2,
        // BD output side
        output logic             rreq,   input  logic rack,
        output logic [WIDTH-1:0] rdata
    );
    
        logic lreq_merged, lack_merged, delayed_lreq;
        logic [WIDTH:0] comb_out;
        logic [WIDTH-1:0] comb_data;

        assign lreq_merged = lreq1 & lreq2;

        AsymmDelayLine #(.DELAY(COMB_DELAY)) DL(.in(lreq_merged), .out(delayed_lreq));

        generate
            if (COMB=="ADD") begin
                adder_gate #(.WIDTH(WIDTH)) C(.opA(ldata1), .opB(ldata2), .sum(comb_out));
            end else begin
                sub_gate   #(.WIDTH(WIDTH)) C(.opA(ldata1), .opB(ldata2), .diff(comb_out));
            end
        endgenerate
        assign #(FL) comb_data = comb_out[WIDTH-1:0];      // drop carry

        FDController #(.WIDTH(WIDTH), .DELAY(CTRL_DELAY)) CC(
            .rst  (rst),
            .lreq (delayed_lreq),  .lack (lack_merged), .ldata(comb_data),
            .rreq (rreq),          .rack (rack),        .rdata(rdata)
        );

        assign lack1 = lack_merged;
        assign lack2 = lack_merged;
    endmodule
