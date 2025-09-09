`timescale 1ns/1ps

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

