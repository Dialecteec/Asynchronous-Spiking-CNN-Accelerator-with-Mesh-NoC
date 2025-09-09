`timescale 1ns/1ps
import SystemVerilogCSP::*;

//------------------------------------------------------------------------------
// Adapter: strip 16-bit mesh header → 48b payload; wrap 48b → 64-bit mesh flit
//------------------------------------------------------------------------------
module mesh_cu_adapter #(
  parameter int SRC_ROW = 0,
  parameter int SRC_COL = 0
)(
  interface mesh_ch_in,
  interface mesh_ch_out,
  interface noc_ch_in,
  interface noc_ch_out
);
  logic [63:0] flit, back_flit;
  logic [47:0] pkt;

  task automatic build_back_flit(
    input  logic [47:0] payload,
    output logic [63:0] f
  );
    logic [3:0] hx = SRC_COL, hy = SRC_ROW;
    logic       dir_x = 1, dir_y = 1;
    begin
      f = { payload,      // [63:16]
            5'd0,         // [15:11]
            dir_y, dir_x, // [10:9]
            hy,           // [8:5]
            hx,           // [4:1]
            1'b0          // [0]
          };
    end
  endtask

  // mesh → CU
  always begin
    mesh_ch_in.Receive(flit);
    $display("%0t [%m] ⟶ mesh→CU flit=%h payload=%h", $time, flit, flit[63:16]);
    pkt = flit[63:16];
    noc_ch_out.Send(pkt);
    $display("%0t [%m]    sent to CU pkt=%h", $time, pkt);
  end

  // CU → mesh
  always begin
    noc_ch_in.Receive(pkt);
    $display("%0t [%m] ⟵ CU→mesh pkt=%h", $time, pkt);
    build_back_flit(pkt, back_flit);
    mesh_ch_out.Send(back_flit);
    $display("%0t [%m]    sent mesh-flit=%h", $time, back_flit);
  end
endmodule


//------------------------------------------------------------------------------
// mesh_scnn_tb.sv : SCNN flow over 2×3 mesh driving CUs 1–5
//------------------------------------------------------------------------------
module mesh_scnn_tb;

  //----------------------------------------------------------------------------
  // PARAMETERS & OPCODES
  //----------------------------------------------------------------------------
  parameter int MESH_W              = 64;
  parameter int CU_W                = 48;
  parameter int ID_WIDTH            = 5;
  parameter int DTYPE_WIDTH         = 3;
  parameter int CMDOPCODE_WIDTH     = 2;
  parameter int DLOAD_WIDTH         = 40;
  parameter int CMDPCKT_WIDTH       = 38;
  parameter int NUMS_WIDTH          = 7;
  parameter int REG_STARTADDR_WIDTH = 5;
  parameter int REG_STRIDE_WIDTH    = 5;
  parameter int THRESHOLD_WIDTH     = 8;
  parameter int I_NUM               = 5;
  parameter int I_WIDTH             = 1;
  parameter int W_NUM               = 5;
  parameter int W_WIDTH             = 8;

  localparam logic [1:0]
    LOADW   = 2'b00,
    LOADI   = 2'b01,
    MAC_CFG = 2'b10,
    MAC     = 2'b11;

  localparam logic [DTYPE_WIDTH-1:0]
    DATA_WEIGHT   = 3'b000,
    DATA_FMAP     = 3'b001,
    DATA_RES      = 3'b010,
    DATA_CMD      = 3'b011,
    DATA_CMDACK   = 3'b100,
    DATA_SPIKERES = 3'b101;

  // CU coordinates in the mesh
  localparam int rows [1:5] = '{ 0, 0, 1, 1, 1 };
  localparam int cols [1:5] = '{ 1, 2, 0, 1, 2 };

  //----------------------------------------------------------------------------
  // STORAGE & WORK SIGNALS
  //----------------------------------------------------------------------------
  logic [W_WIDTH-1:0]           weights_flat   [0:W_NUM*W_NUM-1];
  logic                         flat_ifmap     [0:25*25-1];
  logic [W_WIDTH-1:0]           golden_residue [0:20][0:20];
  logic                         golden_spike   [0:20][0:20];

  logic                         actual_spike;
  logic [W_WIDTH-1:0]           actual_residue;

  logic [W_WIDTH*W_NUM-1:0]     w_data;
  logic [I_WIDTH*I_NUM-1:0]     i_data;
  logic [I_WIDTH-1:0]           i_tmp [0:I_NUM-1];

  logic [63:0]                  flit64, recv64;
  logic [47:0]                  payload48, resp48;

  logic [4:0]                   rd, dest_id;
  logic [2:0]                   dt;
  logic [39:0]                  pl;

  // Controller ↔ mesh
  Channel ctrl_out(), ctrl_in();
    defparam ctrl_out.WIDTH      = CU_W;
    defparam ctrl_out.hsProtocol = P4PhaseBD;
    defparam ctrl_in .WIDTH      = CU_W;
    defparam ctrl_in .hsProtocol = P4PhaseBD;

  logic [CMDPCKT_WIDTH-1:0]                cmdpkg;
  logic [CMDOPCODE_WIDTH+CMDPCKT_WIDTH-1:0] cmdpkt;

  integer id, i, row, col, oy, ox, ky, kx;
  bit     seen [1:5];
  integer log_file;

  //----------------------------------------------------------------------------
  // Mesh ports
  //----------------------------------------------------------------------------
  Channel ctrl2mesh(), mesh2ctrl();
    defparam ctrl2mesh .WIDTH      = MESH_W; defparam ctrl2mesh .hsProtocol = P4PhaseBD;
    defparam mesh2ctrl .WIDTH      = MESH_W; defparam mesh2ctrl .hsProtocol = P4PhaseBD;

  Channel mesh2cu1(), cu12mesh();
    defparam mesh2cu1 .WIDTH      = MESH_W; defparam mesh2cu1 .hsProtocol = P4PhaseBD;
    defparam cu12mesh.WIDTH      = MESH_W; defparam cu12mesh.hsProtocol = P4PhaseBD;
  Channel mesh2cu2(), cu22mesh();
    defparam mesh2cu2 .WIDTH      = MESH_W; defparam mesh2cu2 .hsProtocol = P4PhaseBD;
    defparam cu22mesh.WIDTH      = MESH_W; defparam cu22mesh.hsProtocol = P4PhaseBD;
  Channel mesh2cu3(), cu32mesh();
    defparam mesh2cu3 .WIDTH      = MESH_W; defparam mesh2cu3 .hsProtocol = P4PhaseBD;
    defparam cu32mesh.WIDTH      = MESH_W; defparam cu32mesh.hsProtocol = P4PhaseBD;
  Channel mesh2cu4(), cu42mesh();
    defparam mesh2cu4 .WIDTH      = MESH_W; defparam mesh2cu4 .hsProtocol = P4PhaseBD;
    defparam cu42mesh.WIDTH      = MESH_W; defparam cu42mesh.hsProtocol = P4PhaseBD;
  Channel mesh2cu5(), cu52mesh();
    defparam mesh2cu5 .WIDTH      = MESH_W; defparam mesh2cu5 .hsProtocol = P4PhaseBD;
    defparam cu52mesh.WIDTH      = MESH_W; defparam cu52mesh.hsProtocol = P4PhaseBD;

  Channel cu1_in(), cu1_out();
    defparam cu1_in .WIDTH      = CU_W; defparam cu1_in .hsProtocol = P4PhaseBD;
    defparam cu1_out.WIDTH      = CU_W; defparam cu1_out.hsProtocol = P4PhaseBD;
  Channel cu2_in(), cu2_out();
    defparam cu2_in .WIDTH      = CU_W; defparam cu2_in .hsProtocol = P4PhaseBD;
    defparam cu2_out.WIDTH      = CU_W; defparam cu2_out.hsProtocol = P4PhaseBD;
  Channel cu3_in(), cu3_out();
    defparam cu3_in .WIDTH      = CU_W; defparam cu3_in .hsProtocol = P4PhaseBD;
    defparam cu3_out.WIDTH      = CU_W; defparam cu3_out.hsProtocol = P4PhaseBD;
  Channel cu4_in(), cu4_out();
    defparam cu4_in .WIDTH      = CU_W; defparam cu4_in .hsProtocol = P4PhaseBD;
    defparam cu4_out.WIDTH      = CU_W; defparam cu4_out.hsProtocol = P4PhaseBD;
  Channel cu5_in(), cu5_out();
    defparam cu5_in .WIDTH      = CU_W; defparam cu5_in .hsProtocol = P4PhaseBD;
    defparam cu5_out.WIDTH      = CU_W; defparam cu5_out.hsProtocol = P4PhaseBD;

  //----------------------------------------------------------------------------
  // 2×3 MESH + adapters + CUs
  //----------------------------------------------------------------------------
  mesh #(.FL(0), .BL(0), .WIDTH(MESH_W)) mesh_inst (
    .pe_input_00(ctrl2mesh), .pe_output_00(mesh2ctrl),
    .pe_input_01(mesh2cu1),  .pe_output_01(cu12mesh),
    .pe_input_02(mesh2cu2),  .pe_output_02(cu22mesh),
    .pe_input_10(mesh2cu3),  .pe_output_10(cu32mesh),
    .pe_input_11(mesh2cu4),  .pe_output_11(cu42mesh),
    .pe_input_12(mesh2cu5),  .pe_output_12(cu52mesh)
  );

  mesh_cu_adapter #(.SRC_ROW(0), .SRC_COL(0)) ctrl_adapter (
    .mesh_ch_in (mesh2ctrl), .mesh_ch_out(ctrl2mesh),
    .noc_ch_in  (ctrl_out),  .noc_ch_out(ctrl_in)
  );
  mesh_cu_adapter #(.SRC_ROW(0), .SRC_COL(1)) cu1_adapter (
    .mesh_ch_in (cu12mesh),  .mesh_ch_out(mesh2cu1),
    .noc_ch_in  (cu1_out),   .noc_ch_out(cu1_in)
  );
  mesh_cu_adapter #(.SRC_ROW(0), .SRC_COL(2)) cu2_adapter (
    .mesh_ch_in (cu22mesh),  .mesh_ch_out(mesh2cu2),
    .noc_ch_in  (cu2_out),   .noc_ch_out(cu2_in)
  );
  mesh_cu_adapter #(.SRC_ROW(1), .SRC_COL(0)) cu3_adapter (
    .mesh_ch_in (cu32mesh),  .mesh_ch_out(mesh2cu3),
    .noc_ch_in  (cu3_out),   .noc_ch_out(cu3_in)
  );
  mesh_cu_adapter #(.SRC_ROW(1), .SRC_COL(1)) cu4_adapter (
    .mesh_ch_in (cu42mesh),  .mesh_ch_out(mesh2cu4),
    .noc_ch_in  (cu4_out),   .noc_ch_out(cu4_in)
  );
  mesh_cu_adapter #(.SRC_ROW(1), .SRC_COL(2)) cu5_adapter (
    .mesh_ch_in (cu52mesh),  .mesh_ch_out(mesh2cu5),
    .noc_ch_in  (cu5_out),   .noc_ch_out(cu5_in)
  );

  CU_baseline #(.THIS_CU_ADDR(5'd1), .CTRL_ID(5'd0), .PCKT_WIDTH(CU_W))
    cu1(.Noc_in(cu1_in), .Noc_out(cu1_out));
  CU_baseline #(.THIS_CU_ADDR(5'd2), .CTRL_ID(5'd0), .PCKT_WIDTH(CU_W))
    cu2(.Noc_in(cu2_in), .Noc_out(cu2_out));
  CU_baseline #(.THIS_CU_ADDR(5'd3), .CTRL_ID(5'd0), .PCKT_WIDTH(CU_W))
    cu3(.Noc_in(cu3_in), .Noc_out(cu3_out));
  CU_baseline #(.THIS_CU_ADDR(5'd4), .CTRL_ID(5'd0), .PCKT_WIDTH(CU_W))
    cu4(.Noc_in(cu4_in), .Noc_out(cu4_out));
  CU_baseline #(.THIS_CU_ADDR(5'd5), .CTRL_ID(5'd0), .PCKT_WIDTH(CU_W))
    cu5(.Noc_in(cu5_in), .Noc_out(cu5_out));

  //----------------------------------------------------------------------------
  // build_forward_flit helper
  //----------------------------------------------------------------------------
  function automatic logic [63:0] build_forward_flit(
    input int          drow,
    input int          dcol,
    input logic [47:0] payload
  );
    logic [3:0] hx = dcol, hy = drow;
    logic       dir_x = (dcol==0), dir_y = (drow==0);
    begin
      return { payload, 5'd0, dir_y, dir_x, hy, hx, 1'b0 };
    end
  endfunction

  //----------------------------------------------------------------------------
  // main SCNN flow (round-robin across all 5 CUs)
  //----------------------------------------------------------------------------
    integer res_file;
  initial begin
    // preload (weights and spikes still read the same)
    $readmemh("scnn_data/L1_filter.txt",       weights_flat);
    $readmemb("scnn_data/ifmap_t1.txt",        flat_ifmap);
    $readmemb("scnn_data/L1_out_spike_t1.txt",  golden_spike);

    // golden_residue is now decimal—load with fscanf
    res_file = $fopen("scnn_data/L1_residue_t1.txt","r");
    if (!res_file) $fatal(1, "failed to open residue file");
    for (row = 0; row < 21; row = row + 1) begin
      for (col = 0; col < 21; col = col + 1) begin
        $fscanf(res_file, "%d\n", golden_residue[row][col]);
      end
    end
    $fclose(res_file);

    // open log
    log_file = $fopen("match_mismatch_log.txt","w");
    if (!log_file) $finish;

    #20;

    // 1) LOADW to all CUs
    cmdpkg = { NUMS_WIDTH'(W_NUM), REG_STARTADDR_WIDTH'(0), REG_STRIDE_WIDTH'(1), 12'd0 };
    cmdpkt = { LOADW, cmdpkg };
    for (id=1; id<=5; id++) begin
      payload48 = { id, DATA_CMD, cmdpkt };
      flit64    = build_forward_flit(rows[id], cols[id], payload48);
      ctrl2mesh.Send(flit64);
      seen[id] = 0;
    end

    // send weights
    for (row=0; row<W_NUM; row++) begin
      for (col=0; col<W_NUM; col++)
        w_data[col*W_WIDTH +: W_WIDTH] = weights_flat[row*W_NUM + col];
      for (id=1; id<=5; id++) begin
        payload48 = { id, DATA_WEIGHT, w_data };
        flit64    = build_forward_flit(rows[id], cols[id], payload48);
        ctrl2mesh.Send(flit64);
      end
    end

    // collect ACKs
    for (i=0; i<5; i++) begin
      mesh2ctrl.Receive(recv64);
      resp48 = recv64[63:16];
      { rd, dt, pl } = resp48;
      dest_id = pl[39:35];
      if (dt !== DATA_CMDACK) $error;
      else                   seen[dest_id] = 1;
    end

    // 2) MAC_CFG to all CUs
    cmdpkg = { {(CMDPCKT_WIDTH-28){1'b0}}, 1'b1,1'b0, THRESHOLD_WIDTH'(8'd32), 18'd0 };
    cmdpkt = { MAC_CFG, cmdpkg };
    for (id=1; id<=5; id++) begin
      payload48 = { id, DATA_CMD, cmdpkt };
      flit64    = build_forward_flit(rows[id], cols[id], payload48);
      ctrl2mesh.Send(flit64);
      seen[id] = 0;
    end
    for (i=0; i<5; i++) begin
      mesh2ctrl.Receive(recv64);
      resp48 = recv64[63:16];
      { rd, dt, pl } = resp48;
      if (dt !== DATA_CMDACK) $error;
    end

    // 3) sliding-window MAC + IFMAP + collect results
    for (oy=0; oy<21; oy++) begin
      for (ox=0; ox<21; ox++) begin
        id = ((oy*21 + ox) % 5) + 1;
        // MAC cmd
        cmdpkg   = { {(CMDPCKT_WIDTH-29){1'b0}}, 1'b0, NUMS_WIDTH'(W_NUM), 1'b0,1'b1,1'b1,
                     REG_STARTADDR_WIDTH'(0), REG_STRIDE_WIDTH'(1), 8'd0 };
        cmdpkt   = { MAC, cmdpkg };
        payload48 = { id, DATA_CMD, cmdpkt };
        ctrl2mesh.Send(build_forward_flit(rows[id], cols[id], payload48));
        // IFMAP patches
        for (ky=0; ky<5; ky++) begin
          for (kx=0; kx<5; kx++)
            i_tmp[kx] = flat_ifmap[(oy+ky)*25 + (ox+kx)];
          i_data     = { i_tmp[4],i_tmp[3],i_tmp[2],i_tmp[1],i_tmp[0] };
          payload48  = { id, DATA_FMAP, {(DLOAD_WIDTH-I_NUM){1'b0}}, i_data };
          ctrl2mesh.Send(build_forward_flit(rows[id], cols[id], payload48));
        end
        // result
        mesh2ctrl.Receive(recv64);  resp48 = recv64[63:16];
        { rd, dt, pl } = resp48;
        actual_spike   = pl[DLOAD_WIDTH-1];
        actual_residue = pl[DLOAD_WIDTH-2 -: W_WIDTH];
        if (actual_spike   !== golden_spike  [oy][ox] ||
            actual_residue !== golden_residue[oy][ox]) begin
          $fwrite(log_file,
            "MISMATCH (%0d,%0d): got spike=%b res=%0d, exp spike=%b res=%0d\n",
            oy, ox,
            actual_spike, actual_residue,
            golden_spike[oy][ox], golden_residue[oy][ox]
          );
        end else begin
          $fwrite(log_file,
            "MATCH    (%0d,%0d): got spike=%b res=%0d, exp spike=%b res=%0d\n",
            oy, ox,
            actual_spike, actual_residue,
            golden_spike[oy][ox], golden_residue[oy][ox]
          );
        end
        // ACK
        mesh2ctrl.Receive(recv64); { rd, dt, pl } = recv64[63:16];
      end
    end

    $fwrite(log_file, "# End time: %0t\n", $time);
    #100; $stop;
  end

endmodule
