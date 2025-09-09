`timescale 1ns/1ps
import SystemVerilogCSP::*;

module tb_scnn;

//Initializing Parameters
parameter THIS_CU_ADDR = 5'b10000;
parameter CTRL_ID = 5'b00000;
parameter PCKT_WIDTH = 48; //[dest_id(5), data_type(3), dataload(40)] // 48bits
parameter ID_WIDTH = 5; // dest_id 5bits
parameter DTYPE_WIDTH = 3; // data_type 3bits
parameter CMDOPCODE_WIDTH   = 2;
parameter DLOAD_WIDTH = 40; // dataload 40bits
parameter CMDPCKT_WIDTH     = 38;
parameter NUMS_WIDTH            = 7;
parameter REG_STARTADDR_WIDTH   = 5;
parameter REG_STRIDE_WIDTH      = 5;
parameter REGCTRL_WIDTH         = 7;

parameter THRESHOLD_WIDTH           = 8;
parameter MAC_NUMS_WIDTH            = 7;
parameter MAC_REG_STARTADDR_WIDTH   = 5; 
parameter MAC_REG_STRIDE            = 5;
parameter MAC_OUT_STARTADDR         = 8;
//Command opcodes 
parameter LOADW    = 2'b00;
parameter LOADI    = 2'b01;
parameter MAC_CFG  = 2'b10;
parameter MAC      = 2'b11;
//Data type
parameter DATA_WEIGHT = 3'b000;
parameter DATA_FMAP   = 3'b001;
parameter DATA_RES    = 3'b010;
parameter DATA_CMD    = 3'b011;
parameter DATA_CMDACK    = 3'b100;
parameter DATA_SPIKERES    = 3'b101;

parameter I_NUM     =5;
parameter I_WIDTH   =1;
parameter I_DEPTH   =1;
parameter W_NUM     =5;
parameter W_WIDTH   =8;
parameter W_DEPTH   =9;
parameter R_WIDTH   =8;
parameter R_DEPTH   =9;
parameter P_WIDTH = 8; 

//Delay
parameter DEPACKETIZER_FL = 8;
parameter DEPACKETIZER_BL = 2;
parameter REG_FL = 8;
parameter REG_BL = 2;
parameter CTRL_FL = 4;
parameter CTRL_BL = 2;
parameter PE_FL = 8;
parameter PE_BL = 2;
parameter FL = 8;
parameter BL = 2;

//Initializing Variables
logic [PCKT_WIDTH-1:0] data_pckt;
logic [ID_WIDTH-1:0] dest_id;
logic [DTYPE_WIDTH-1:0] data_type;
logic [DLOAD_WIDTH-1:0] dataload;
logic [DLOAD_WIDTH-1:0]     cmd_pckt;
logic [CMDOPCODE_WIDTH-1:0] cmd_opcode;
logic [CMDPCKT_WIDTH-1 : 0] cmdpackage;
logic [NUMS_WIDTH-1 : 0]            w_cmd_nums;
logic [REG_STARTADDR_WIDTH-1 : 0]   w_cmd_regStartAddr;
logic [REG_STRIDE_WIDTH-1 : 0]      w_cmd_regStride;
logic [11:0] redundant12 = 12'd0;
logic [NUMS_WIDTH-1 : 0]            i_cmd_nums;
logic [REG_STARTADDR_WIDTH-1 : 0]   i_cmd_regStartAddr;
logic [REG_STRIDE_WIDTH-1 : 0]      i_cmd_regStride;
logic ws;
logic is;
logic [THRESHOLD_WIDTH-1 : 0] mac_cfg_threshold; 
logic [17:0] redundant18 = 18'd0;
logic                           last_spike;
logic [MAC_NUMS_WIDTH-1 : 0]    mac_nums;
logic                           resin_flag;
logic                           cmp_cmpn;
logic                           resout_flag;
logic [MAC_REG_STARTADDR_WIDTH-1 : 0]   mac_reg_startaddr;
logic [MAC_REG_STRIDE-1 : 0]            mac_reg_stride;
logic [MAC_OUT_STARTADDR-1 : 0]         mac_out_startaddr;

logic [W_WIDTH-1 : 0]       w_tmp [W_NUM-1 : 0];
logic [W_WIDTH*W_NUM-1 : 0] w_data;

logic [ID_WIDTH-1:0] cu_id;
logic [CMDOPCODE_WIDTH+5-1 :0] ack_data;
logic [27:0] redundant28=0;
logic [R_WIDTH-1 : 0] r_data;

logic [I_WIDTH-1 : 0]       i_tmp [I_NUM-1 : 0];
logic [I_WIDTH*W_NUM-1 : 0] i_data;

logic s_result;
logic [7:0] r_result;
logic [7:0] address;
logic [21:0] redundant22=0;

logic [W_WIDTH-1:0] weights_flat [0:24];
logic flat_ifmap [0:624];
logic [0:24][0:24] ifmap;

logic golden_spike [0:20][0:20];
logic [7:0] golden_residue [0:20][0:20];
logic result_spike [0:20][0:20];
logic [7:0] result_residue [0:20][0:20];
int idx;
logic [W_WIDTH-1:0] weight;
logic [I_WIDTH-1:0] input_val;
integer log_file;

// preload filter, ifmap, spikes
initial $readmemh("scnn_data/L1_filter.txt", weights_flat);
initial $readmemb("scnn_data/ifmap_t1.txt", flat_ifmap);
initial $readmemb("scnn_data/L1_out_spike_t1.txt", golden_spike);

// ── now read residue file as decimal via fscanf, preserving all comments ──
initial begin
  integer fh, status;
  fh = $fopen("scnn_data/L1_residue_t1.txt", "r");
  if (fh == 0) begin
    $display("ERROR: Cannot open L1_residue_t1.txt");
    $finish;
  end
  for (int i = 0; i < 21; i++) begin
    for (int j = 0; j < 21; j++) begin
      status = $fscanf(fh, "%d\n", golden_residue[i][j]);
      // if (status != 1) $display("fscanf failed at [%0d][%0d]", i, j);
    end
  end
  $fclose(fh);
end

// build 2D ifmap array
initial begin
  log_file = $fopen("match_mismatch_log.txt", "w");
  if (!log_file) begin
    $display("ERROR: Cannot open log file!");
    $finish;
  end
  for (int i = 0; i < 25; i++)
    for (int j = 0; j < 25; j++)
      ifmap[i][j] = flat_ifmap[i * 25 + j];
end

Channel #(.hsProtocol(P4PhaseBD), .WIDTH(PCKT_WIDTH))  Noc_in();
Channel #(.hsProtocol(P4PhaseBD), .WIDTH(PCKT_WIDTH))  Noc_out();

CU_baseline #(
  .I_DEPTH(9)
) dut (
  .Noc_in(Noc_in),
  .Noc_out(Noc_out)
);

//test
initial begin
    #20;

    // load weights
    task_sendcommand( LOADW );
    for (int i = 0; i < 5; i++) begin
        for (int j = 0; j < W_NUM; j++)
            w_data[j*W_WIDTH +: W_WIDTH] = weights_flat[i*5 + j];
        task_sendweight(w_data);
    end
    task_cmdackcheck();
    
    // weight load check
    $display("=== w_reg Contents as 5x5 Matrix ===");
    for (int row = 0; row < 5; row++) begin
        $write("Row %0d: ", row);
        for (int col = 0; col < 5; col++) begin
            idx = col * W_WIDTH;
            weight = tb_scnn.dut.w_reg_unit.w_reg[row][idx +: W_WIDTH];
            $write("%0d ", weight);
        end
        $write("\n");
    end

    // MAC_CFG send
    task_sendcommand( MAC_CFG );
    task_cmdackcheck();

    // MAC send
    for (int oy = 0; oy < 21; oy++) begin
        for (int ox = 0; ox < 21; ox++) begin
            // Send MAC Command
            task_sendcommand( MAC );

            // Send 5 input rows (5x5 patch per MAC)
            for (int ky = 0; ky < 5; ky++) begin
                for (int kx = 0; kx < 5; kx++) begin
                    i_tmp[kx] = ifmap[oy + ky][ox + kx];
                end
                i_data = {i_tmp[4], i_tmp[3], i_tmp[2], i_tmp[1], i_tmp[0]};
                task_sendifmap(i_data);
            end

            // Receive result
            task_receiveresult(result_spike[oy][ox], result_residue[oy][ox]);
            if (result_spike[oy][ox] !== golden_spike[oy][ox] ||
                result_residue[oy][ox] !== golden_residue[oy][ox]) begin
                $display("MISMATCH @ [%d][%d]: spike=%b, residue=%0d (exp %0d)", oy, ox, 
                    result_spike[oy][ox], result_residue[oy][ox],
                    golden_spike[oy][ox],    golden_residue[oy][ox]);
                $fdisplay(log_file, "MISMATCH @ [%d][%d]: spike=%b, residue=%0d (exp %0d)", 
                    oy, ox, result_spike[oy][ox], result_residue[oy][ox],
                    golden_spike[oy][ox],    golden_residue[oy][ox]);
            end
            else begin
                $display("MATCH    @ [%d][%d]: spike=%b, residue=%0d", oy, ox, 
                    result_spike[oy][ox], result_residue[oy][ox]);
                $fdisplay(log_file, "MATCH    @ [%d][%d]: spike=%b, residue=%0d", 
                    oy, ox, result_spike[oy][ox], result_residue[oy][ox]);
            end
            task_cmdackcheck();
            #10;
        end
    end

    #200;
    $stop;
end

task static task_receiveresult( output logic spike, output logic [R_WIDTH-1:0] residue );
begin
    Noc_out.Receive(data_pckt);
    {dest_id,data_type,spike, residue, address, last_spike, redundant22} = data_pckt;
end
endtask

task static task_sendifmap( input logic [I_WIDTH*I_NUM-1:0] ifmap );
begin
    dest_id = THIS_CU_ADDR;
    data_type = DATA_FMAP;
    dataload = {35'd0,ifmap};
    data_pckt = {dest_id, data_type, dataload};
    Noc_in.Send(data_pckt);
end
endtask

task static task_sendres( input logic [R_WIDTH-1:0] residue );
begin
    dest_id = THIS_CU_ADDR;
    data_type = DATA_RES;
    dataload = {32'd0,residue};
    data_pckt = {dest_id, data_type, dataload};
    Noc_in.Send(data_pckt);
end
endtask

task static task_cmdackcheck();
begin
    Noc_out.Receive(data_pckt);
    {dest_id,data_type,cu_id, ack_data, redundant28} = data_pckt;
    {cu_id, cmd_opcode} = ack_data;
end
endtask

task static task_sendweight( input logic [W_WIDTH*W_NUM-1:0] weight );
begin
    dest_id = THIS_CU_ADDR;
    data_type = DATA_WEIGHT;
    dataload = w_data;
    data_pckt = {dest_id, data_type, dataload};
    Noc_in.Send(data_pckt);
end
endtask

task automatic task_sendcommand(input logic [1:0] cmdtype, input logic last_flag = 1'b0);
begin
    case (cmdtype)
        LOADW: begin
            w_cmd_nums          =5;
            w_cmd_regStartAddr  =0;
            w_cmd_regStride     =1;
            cmdpackage = {w_cmd_nums, w_cmd_regStartAddr, w_cmd_regStride, redundant12};
        end
        LOADI: begin
            i_cmd_nums          =5;
            i_cmd_regStartAddr  =0;
            i_cmd_regStride     =1;
            cmdpackage = {i_cmd_nums, i_cmd_regStartAddr, i_cmd_regStride, redundant12};
        end
        MAC_CFG: begin
            ws =1;
            is =0;
            mac_cfg_threshold = 8'd32;
            cmdpackage = {ws, is, mac_cfg_threshold, redundant18};
        end
        MAC: begin
            last_spike = last_flag;
            mac_nums = 5;
            resin_flag = 0;
            resout_flag = 1;
            cmp_cmpn = 1;
            mac_reg_startaddr = 0;
            mac_reg_stride = 1;
            mac_out_startaddr = 0;
            cmdpackage = {last_spike, mac_nums, resin_flag, resout_flag, cmp_cmpn, mac_reg_startaddr, mac_reg_stride, mac_out_startaddr};
        end
        default: begin
            $display("%m Incorrect COMMAND!!!");
        end
    endcase

    cmd_opcode = cmdtype;
    cmd_pckt = {cmd_opcode, cmdpackage} ;
    dest_id = THIS_CU_ADDR;
    data_type = DATA_CMD;
    dataload = cmd_pckt;
    data_pckt = {dest_id, data_type, dataload};
    Noc_in.Send(data_pckt);
end
endtask

endmodule
