`timescale 1ns/1ns

module tb_dmem;

  localparam int IFMAP_RDADDR_WIDTH    = 10;
  localparam int IFMAP_RDDATA_DIM      = 5;

  localparam int KERNAL_RDADDR_WIDTH   = 6;
  localparam int KERNAL_RDDATA_DIM     = 5;

  localparam int SPIKE_WRADDR_WIDTH    = 10;
  localparam int SPIKE_WRDATA_DIM      = 5;

  localparam int RESIDUE1_RDADDR_WIDTH = 10;
  localparam int RESIDUE1_RDDATA_DIM   = 5;
  localparam int RESIDUE1_WRADDR_WIDTH = 10;
  localparam int RESIDUE1_WRDATA_DIM   = 5;

  localparam int RESIDUE2_WRADDR_WIDTH = 10;
  localparam int RESIDUE2_WRDATA_DIM   = 5;

  // ifmaps => 5×5=25 bits
  localparam int IFMAP_ADDR_CH_WIDTH = IFMAP_RDADDR_WIDTH;
  localparam int IFMAP_DATA_CH_WIDTH = IFMAP_RDDATA_DIM * IFMAP_RDDATA_DIM;  // 25

  // kernal => 5×(5×3)=75 bits
  localparam int KERNAL_ADDR_CH_WIDTH = KERNAL_RDADDR_WIDTH;
  localparam int KERNAL_DATA_CH_WIDTH = KERNAL_RDDATA_DIM*(KERNAL_RDDATA_DIM*3);  // 75

  // spike => 5×5=25 bits
  localparam int SPIKE_ADDR_CH_WIDTH = SPIKE_WRADDR_WIDTH;
  localparam int SPIKE_DATA_CH_WIDTH = SPIKE_WRDATA_DIM * SPIKE_WRDATA_DIM;  // 25

  // residue => 5×(5×64)=1600 bits
  localparam int RES1_RDADDR_CH_WIDTH = RESIDUE1_RDADDR_WIDTH;
  localparam int RES1_RDDATA_CH_WIDTH = RESIDUE1_RDDATA_DIM*(RESIDUE1_RDDATA_DIM*64);  // 1600
  localparam int RES1_WRADDR_CH_WIDTH = RESIDUE1_WRADDR_WIDTH;
  localparam int RES1_WRDATA_CH_WIDTH = RESIDUE1_WRDATA_DIM*(RESIDUE1_WRDATA_DIM*64);  // 1600

  localparam int RES2_WRADDR_CH_WIDTH = RESIDUE2_WRADDR_WIDTH;
  localparam int RES2_WRDATA_CH_WIDTH = RESIDUE2_WRDATA_DIM*(RESIDUE2_WRDATA_DIM*64);  // 1600


  // ifmap1
  Channel #(.WIDTH(IFMAP_ADDR_CH_WIDTH)) ifmap1_Addr();
  Channel #(.WIDTH(IFMAP_DATA_CH_WIDTH)) ifmap1_Data();

  // ifmap2
  Channel #(.WIDTH(IFMAP_ADDR_CH_WIDTH)) ifmap2_Addr();
  Channel #(.WIDTH(IFMAP_DATA_CH_WIDTH)) ifmap2_Data();

  // kernal
  Channel #(.WIDTH(KERNAL_ADDR_CH_WIDTH)) kernal_Addr();
  Channel #(.WIDTH(KERNAL_DATA_CH_WIDTH)) kernal_Data();

  // spike1
  Channel #(.WIDTH(SPIKE_ADDR_CH_WIDTH)) spike1_Addr();
  Channel #(.WIDTH(SPIKE_DATA_CH_WIDTH)) spike1_Data();

  // spike2
  Channel #(.WIDTH(SPIKE_ADDR_CH_WIDTH)) spike2_Addr();
  Channel #(.WIDTH(SPIKE_DATA_CH_WIDTH)) spike2_Data();

  // residue1 read
  Channel #(.WIDTH(RES1_RDADDR_CH_WIDTH)) residue1_readAddr();
  Channel #(.WIDTH(RES1_RDDATA_CH_WIDTH)) residue1_readData();

  // residue1 write
  Channel #(.WIDTH(RES1_WRADDR_CH_WIDTH)) residue1_writeAddr();
  Channel #(.WIDTH(RES1_WRDATA_CH_WIDTH)) residue1_writeData();

  // residue2 write
  Channel #(.WIDTH(RES2_WRADDR_CH_WIDTH)) residue2_Addr();
  Channel #(.WIDTH(RES2_WRDATA_CH_WIDTH)) residue2_Data();

  dmem #(
    .IFMAP_RDADDR_WIDTH    (IFMAP_RDADDR_WIDTH),
    .IFMAP_RDDATA_DIM      (IFMAP_RDDATA_DIM),

    .KERNAL_RDADDR_WIDTH   (KERNAL_RDADDR_WIDTH),
    .KERNAL_RDDATA_DIM     (KERNAL_RDDATA_DIM),

    .SPIKE_WRADDR_WIDTH    (SPIKE_WRADDR_WIDTH),
    .SPIKE_WRDATA_DIM      (SPIKE_WRDATA_DIM),

    .RESIDUE1_RDADDR_WIDTH (RESIDUE1_RDADDR_WIDTH),
    .RESIDUE1_RDDATA_DIM   (RESIDUE1_RDDATA_DIM),
    .RESIDUE1_WRADDR_WIDTH (RESIDUE1_WRADDR_WIDTH),
    .RESIDUE1_WRDATA_DIM   (RESIDUE1_WRDATA_DIM),

    .RESIDUE2_WRADDR_WIDTH (RESIDUE2_WRADDR_WIDTH),
    .RESIDUE2_WRDATA_DIM   (RESIDUE2_WRDATA_DIM),

    .FL(0),
    .BL(0)
  ) dut (
    .ifmap1_Addr           (ifmap1_Addr),
    .ifmap1_Data           (ifmap1_Data),
    .ifmap2_Addr           (ifmap2_Addr),
    .ifmap2_Data           (ifmap2_Data),

    .kernal_Addr           (kernal_Addr),
    .kernal_Data           (kernal_Data),

    .spike1_Addr           (spike1_Addr),
    .spike1_Data           (spike1_Data),
    .spike2_Addr           (spike2_Addr),
    .spike2_Data           (spike2_Data),

    .residue1_readAddr     (residue1_readAddr),
    .residue1_readData     (residue1_readData),
    .residue1_writeAddr    (residue1_writeAddr),
    .residue1_writeData    (residue1_writeData),

    .residue2_Addr         (residue2_Addr),
    .residue2_Data         (residue2_Data)
  );


  initial begin : TEST_LOGIC

    int row, col;
    
    // ifmap read
    logic [IFMAP_ADDR_CH_WIDTH-1:0] ifmap_rd_addr;
    logic [IFMAP_DATA_CH_WIDTH-1:0] ifmap_rd_data;

    // kernal read
    logic [KERNAL_ADDR_CH_WIDTH-1:0] kern_addr;
    logic [KERNAL_DATA_CH_WIDTH-1:0] kern_data;

    // residue1 read/write
    logic [RES1_RDADDR_CH_WIDTH-1:0] res1_rd_addr;
    logic [RES1_RDDATA_CH_WIDTH-1:0] res1_rd_data;
    logic [RES1_WRADDR_CH_WIDTH-1:0] res1_wr_addr;
    logic [RES1_WRDATA_CH_WIDTH-1:0] res1_wr_data;

    // spike write
    logic [SPIKE_ADDR_CH_WIDTH-1:0] spike1_wr_addr;
    logic [SPIKE_DATA_CH_WIDTH-1:0] spike1_wr_data;
    logic [SPIKE_ADDR_CH_WIDTH-1:0] spike2_wr_addr;
    logic [SPIKE_DATA_CH_WIDTH-1:0] spike2_wr_data;

    // residue2 write
    logic [RES2_WRADDR_CH_WIDTH-1:0] res2_wr_addr;
    logic [RES2_WRDATA_CH_WIDTH-1:0] res2_wr_data;

    integer i;

    #100;
    $display("\n[TB] Starting test sequence...\n");

    // ============ READ ifmap1 @ (row=0,col=0) ============
    row = 0; col = 0;
    ifmap_rd_addr = {col[4:0], row[4:0]};
    $display("[TB] ifmap1: reading submatrix row=%0d,col=%0d => addr=0x%h", row, col, ifmap_rd_addr);

    ifmap1_Addr.Send(ifmap_rd_addr);
    ifmap1_Data.Receive(ifmap_rd_data);
    $display("[TB] ifmap1: got 25 bits submatrix = %b", ifmap_rd_data);

    // ============ READ ifmap2 @ (row=10,col=10) ============
    row = 10; col = 10;
    ifmap_rd_addr = {col[4:0], row[4:0]}; 
    $display("[TB] ifmap2: reading submatrix row=%0d,col=%0d => 0x%h", row, col, ifmap_rd_addr);

    ifmap2_Addr.Send(ifmap_rd_addr);
    ifmap2_Data.Receive(ifmap_rd_data);
    $display("[TB] ifmap2: got submatrix = %b", ifmap_rd_data);

    // ============ READ kernal @ (row=2,col=0) ============
    // 6-bit address => top 3 bits=col, bottom 3 bits=row
    row = 2; col = 0;
    kern_addr = {col[2:0], row[2:0]};
    $display("[TB] kernal: reading submatrix row=%0d,col=%0d => 0x%h", row, col, kern_addr);

    kernal_Addr.Send(kern_addr);
    kernal_Data.Receive(kern_data);
    $display("[TB] kernal: got 75 bits submatrix = %b", kern_data);

    // ============ WRITE residue1 @ (row=1,col=1) ============
    // => submatrix is 5x5=25 elements of 64 bits => total 1600 bits
    row = 1;
    col = 1;
    res1_wr_addr = {col[4:0], row[4:0]};
    $display("[TB] residue1: writing submatrix row=%0d,col=%0d => addr=0x%h", row, col, res1_wr_addr);

    // fill the 1600-bit data with a pattern
    for (i=0; i<1600; i++) begin
      // set first ~64 bits to 1, rest 0 for example
      res1_wr_data[i] = (i < 64) ? 1'b1 : 1'b0;
    end

    residue1_writeAddr.Send(res1_wr_addr);
    residue1_writeData.Send(res1_wr_data);
    $display("[TB] residue1: wrote 1600 bits (lower 64 bits = 1, rest = 0).");

    // ============ READ residue1 @ (row=1,col=1) again ============
    res1_rd_addr = {col[4:0], row[4:0]};
    $display("[TB] residue1: now reading back row=%0d,col=%0d => 0x%h", row, col, res1_rd_addr);

    residue1_readAddr.Send(res1_rd_addr);
    residue1_readData.Receive(res1_rd_data);
    $display("[TB] residue1: read-back lower 64 bits = %h", res1_rd_data[63:0]);

    // ============ WRITE spike1 @ (row=5,col=5) -> 25 bits ============
    row = 5; 
    col = 5;
    spike1_wr_addr = {col[4:0], row[4:0]};
    spike1_wr_data = 25'b10101_01010_11111_00000_11011; // some pattern

    $display("[TB] spike1: writing row=%0d,col=%0d => 0x%h, data=%b",
             row, col, spike1_wr_addr, spike1_wr_data);
    spike1_Addr.Send(spike1_wr_addr);
    spike1_Data.Send(spike1_wr_data);

    // ============ WRITE spike2 @ (row=5,col=5) -> 25 bits ============
    spike2_wr_addr = {col[4:0], row[4:0]};
    spike2_wr_data = 25'b00000_11111_00000_10101_01010; // different pattern
    $display("[TB] spike2: writing row=%0d,col=%0d => 0x%h, data=%b",
             row, col, spike2_wr_addr, spike2_wr_data);
    spike2_Addr.Send(spike2_wr_addr);
    spike2_Data.Send(spike2_wr_data);

    // ============ WRITE residue2 @ (row=3,col=3) -> 1600 bits ============
    row = 3;
    col = 3;
    res2_wr_addr = {col[4:0], row[4:0]};
    $display("[TB] residue2: writing row=%0d,col=%0d => 0x%h",
             row, col, res2_wr_addr);

    // fill 1600 bits with a pattern
    for (i=0; i<1600; i++) begin
        // set bits 32..63 = 1, rest 0
        if ((i >=32) && (i<64)) res2_wr_data[i] = 1'b1;
        else                   res2_wr_data[i] = 1'b0;
    end

    residue2_Addr.Send(res2_wr_addr);
    residue2_Data.Send(res2_wr_data);
    $display("[TB] residue2: wrote 1600 bits with bits[32..63]=1");

    // Done with test
    #200;
    $display("\n[TB] Test done. The final text files (spike1_out, spike2_out, residue1_out, residue2_out) ");
    $display("     will be generated by the 'final' block in dmem.\n");
    $finish;
  end

endmodule
