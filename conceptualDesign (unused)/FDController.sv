`timescale 1ns/1ps

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