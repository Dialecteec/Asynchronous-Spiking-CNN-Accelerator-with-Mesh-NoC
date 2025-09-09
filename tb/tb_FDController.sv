`timescale 1ns/1ps

module tb_FDController;

  parameter WIDTH = 8;
  parameter DELAY = 2;

  reg             rst;
  reg             lreq;
  reg             rack;
  reg [WIDTH-1:0] ldata;
  wire            lack;
  wire            rreq;
  wire [WIDTH-1:0] rdata;

  FDController #(
    .WIDTH(WIDTH),
    .DELAY(DELAY)
  ) dut (
    .rst(rst),
    .lreq(lreq),
    .rack(rack),
    .ldata(ldata),
    .lack(lack),
    .rreq(rreq),
    .rdata(rdata)
  );

  reg [WIDTH-1:0] golden_rdata;

  task compare_outputs;
    input [WIDTH-1:0] dut_val;
    input [WIDTH-1:0] golden_val;
    begin
      if (dut_val !== golden_val)
        $display("MISMATCH at time %0t: DUT rdata = %h, golden rdata = %h", $time, dut_val, golden_val);
      else
        $display("MATCH   at time %0t: DUT rdata = %h, golden rdata = %h", $time, dut_val, golden_val);
    end
  endtask

  initial begin
    $display("Time\tlreq\track\tldata\trdata\tGolden_rdata");
    $display("-----------------------------------------------------------");

    rst   = 1;
    lreq  = 0;
    rack  = 0;
    ldata = 0;
    golden_rdata = 0;

    #5;
    rst = 0;
    #5;
    
    // --- Transaction 1 ---
    ldata = 8'hAA;
    lreq  = 1;
    golden_rdata = 8'hAA;
    $display("%0t\t%b\t%b\t%h\t%h\t%h", $time, lreq, rack, ldata, rdata, golden_rdata);

    #10;

    rack = 1;

    #5;

    $display("%0t\t%b\t%b\t%h\t%h\t%h", $time, lreq, rack, ldata, rdata, golden_rdata);
    compare_outputs(rdata, golden_rdata);

    #5;

    lreq = 0;
    rack = 0;

    #10;

    $display("%0t\t%b\t%b\t%h\t%h\t%h", $time, lreq, rack, ldata, rdata, golden_rdata);
    compare_outputs(rdata, golden_rdata);
    
    #20;
    
    // --- Transaction 2 ---
    ldata = 8'h55;
    lreq  = 1;
    golden_rdata = 8'h55;
    $display("%0t\t%b\t%b\t%h\t%h\t%h", $time, lreq, rack, ldata, rdata, golden_rdata);
    #10;
    rack = 1;
    #5;
    $display("%0t\t%b\t%b\t%h\t%h\t%h", $time, lreq, rack, ldata, rdata, golden_rdata);
    compare_outputs(rdata, golden_rdata);

    #5;

    lreq = 0;
    rack = 0;

    #10;

    $display("%0t\t%b\t%b\t%h\t%h\t%h", $time, lreq, rack, ldata, rdata, golden_rdata);
    compare_outputs(rdata, golden_rdata);

    #50;
    
    $finish;
  end

endmodule
