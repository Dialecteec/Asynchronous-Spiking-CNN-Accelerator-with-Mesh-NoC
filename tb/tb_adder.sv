`timescale 1ns/1ps
module tb_adder;

    parameter WIDTH = 10;
    parameter FL    = 6;
    parameter COMB_DELAY = 1;
    parameter CTRL_DELAY = 1;

    reg             rst;
    reg             lreq1, lreq2;
    reg  [WIDTH-1:0] ldata1, ldata2;
    wire            lack1, lack2;

    wire            rreq;
    reg             rack;
    wire [WIDTH-1:0] rdata;

    reg [WIDTH:0] golden_sum;

  adder #(
    .WIDTH(WIDTH),
    .FL(FL),
    .COMB_DELAY(COMB_DELAY),
    .CTRL_DELAY(CTRL_DELAY)
  ) dut (
    .rst    (rst),
    .lreq1  (lreq1),
    .lack1  (lack1),
    .ldata1 (ldata1),
    .lreq2  (lreq2),
    .lack2  (lack2),
    .ldata2 (ldata2),
    .rreq   (rreq),
    .rack   (rack),
    .rdata  (rdata)
  );

  initial begin
    $display("Time\t rst\t lreq1\t ldata1\t lreq2\t ldata2\t rack\t rreq\t rdata\t Golden");
    $display("----------------------------------------------------------------------------------------");
  end
  
  initial begin
    rst    = 1;
    lreq1  = 0;
    lreq2  = 0;
    ldata1 = 0;
    ldata2 = 0;
    rack   = 0;
    golden_sum = 0;
    
    #10;
    rst = 0;
    $display("%0t\t %b\t %b\t %d\t %b\t %d\t %b\t --\t --\t %d", 
             $time, rst, lreq1, ldata1, lreq2, ldata2, rack, golden_sum);
    
    // ---------------- Transaction 1 ----------------
    lreq1 = 0;
    lreq2 = 0;
    #5;

    ldata1 = 10'd123;
    ldata2 = 10'd456;
    golden_sum = ldata1 + ldata2;

    lreq1 = 1;
    lreq2 = 1;
    $display("%0t\t %b\t %b\t %d\t %b\t %d\t %b\t --\t --\t %d", 
             $time, rst, lreq1, ldata1, lreq2, ldata2, rack, golden_sum);
 
    #15;
    rack = 1;
    #5;
    
    $display("%0t\t %b\t %b\t %d\t %b\t %d\t %b\t %b\t %d\t %d", 
             $time, rst, lreq1, ldata1, lreq2, ldata2, rack, rreq, rdata, golden_sum[WIDTH-1:0]);
    
    if (rdata === golden_sum[WIDTH-1:0])
        $display("Transaction 1 PASS: rdata = %d matches golden = %d", rdata, golden_sum[WIDTH-1:0]);
    else
        $display("Transaction 1 FAIL: rdata = %d, expected = %d", rdata, golden_sum[WIDTH-1:0]);

    #5;
    lreq1 = 0;
    lreq2 = 0;
    rack  = 0;

    #20;
    
    // ---------------- Transaction 2 ----------------
    lreq1 = 0;
    lreq2 = 0;
    #5;

    ldata1 = 10'd800;
    ldata2 = 10'd100;
    golden_sum = ldata1 + ldata2;

    lreq1 = 1;
    lreq2 = 1;
    $display("%0t\t %b\t %b\t %d\t %b\t %d\t %b\t --\t --\t %d", 
             $time, rst, lreq1, ldata1, lreq2, ldata2, rack, golden_sum);
    
    #15;
    rack = 1;
    #5;
    
    $display("%0t\t %b\t %b\t %d\t %b\t %d\t %b\t %b\t %d\t %d", 
             $time, rst, lreq1, ldata1, lreq2, ldata2, rack, rreq, rdata, golden_sum[WIDTH-1:0]);
    
    if (rdata === golden_sum[WIDTH-1:0])
      $display("Transaction 2 PASS: rdata = %d matches golden = %d", rdata, golden_sum[WIDTH-1:0]);
    else
      $display("Transaction 2 FAIL: rdata = %d, expected = %d", rdata, golden_sum[WIDTH-1:0]);
    
    #10;
    $finish;
  end

endmodule
