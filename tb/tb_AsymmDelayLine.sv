`timescale 1ns/1ps

module tb_AsymmDelayLine;

  parameter real DELAY = 1.0;

  logic in;
  logic out;

  AsymmDelayLine #(
    .DELAY(DELAY)
  ) dut (
    .in(in),
    .out(out)
  );

  initial begin
    in  = 0;
    #5;

    in = 1;
    #5;
    in = 0;
    #5;

    $finish;
  end

endmodule
