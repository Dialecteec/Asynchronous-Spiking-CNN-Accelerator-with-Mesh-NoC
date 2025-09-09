`timescale 1ns/1ns
import SystemVerilogCSP::*;

//data_bucket module
module data_bucket (interface r);
parameter WIDTH = 8;
parameter BL = 0; //ideal environment   no backward delay

logic [WIDTH-1:0] ReceiveValue = 0;
logic [47:0] received_data_array [0:1023]; // store up to 1024 packets
int index = 0;

initial begin
    foreach (received_data_array[i]) begin
        received_data_array[i] = '0;  // Set each element to zero
    end
end

always
begin

    r.Receive(ReceiveValue);
    
    // Extract bits [63:16] and store in array
    received_data_array[index] = ReceiveValue[63:16];
    
    $display("Finished receiving in module %m @%t: full_packet=%h, extracted_data[63:16]=%h", 
          $time, ReceiveValue, received_data_array[index]);
          
    index++; 
    
    #BL;
end
endmodule

module async_router_tb ();

    // Parameter definitions
    parameter WIDTH = 64;
    parameter FL = 0;
    parameter BL = 0;
    logic [WIDTH-1:0] packet;
    logic [WIDTH-1:0] packet1;
    logic [WIDTH-1:0] packet2;
    logic [WIDTH-1:0] packet3;
    logic [WIDTH-1:0] packet4;
    
    int pass_count = 0;
    int fail_count = 0;
    
    //Expected data constant 
    localparam int NUM_EXPECTED = 4;
    localparam logic [47:0] expected_cw_output [0:NUM_EXPECTED-1] = '{
        48'hAAAA_AAAA_AAAA, // From CW input
        48'hBBBB_BBBB_BBBB, // From SN input
        48'hBBBB_BBBB_BBBB, // From NS input
        48'hAAAA_AAAA_AAAA  // From PE input
    };

     localparam logic [47:0] expected_ccw_output [0:NUM_EXPECTED-1] = '{
        48'hAAAA_AAAA_AAAA, // From CCW input
        48'hCCCC_CCCC_CCCC, // From SN input
        48'hCCCC_CCCC_CCCC, // From NS input
        48'hBBBB_BBBB_BBBB // From PE input
     };
     
     localparam logic [47:0] expected_sn_output [0:NUM_EXPECTED-1] = '{
        48'hBBBB_BBBB_BBBB, // From CW input
        48'hBBBB_BBBB_BBBB, // From CCW input
        48'hAAAA_AAAA_AAAA, // From SN input
        48'hDDDD_DDDD_DDDD // From PE input
     };
     
     localparam logic [47:0] expected_ns_output [0:NUM_EXPECTED-1] = '{
         48'hCCCC_CCCC_CCCC, // From CW input
         48'hCCCC_CCCC_CCCC, // From CCW input
         48'hAAAA_AAAA_AAAA, // From NS input
         48'hCCCC_CCCC_CCCC  // From PE input
     };
     
     
     localparam logic [47:0] expected_pe_output [0:NUM_EXPECTED-1] = '{
         48'hDDDD_DDDD_DDDD, // From CW input
         48'hDDDD_DDDD_DDDD, // From CCW input
         48'hDDDD_DDDD_DDDD, // From SN input
         48'hDDDD_DDDD_DDDD  // From NS input
     };
 
    
    // External Input/Output Channel Interfaces
    Channel #(.WIDTH(WIDTH), .hsProtocol(P4PhaseBD)) cw_input ();
    Channel #(.WIDTH(WIDTH), .hsProtocol(P4PhaseBD)) cw_output ();
    
    Channel #(.WIDTH(WIDTH), .hsProtocol(P4PhaseBD)) ccw_input ();
    Channel #(.WIDTH(WIDTH), .hsProtocol(P4PhaseBD)) ccw_output ();
    
    Channel #(.WIDTH(WIDTH), .hsProtocol(P4PhaseBD)) ns_input ();
    Channel #(.WIDTH(WIDTH), .hsProtocol(P4PhaseBD)) ns_output ();
    
    Channel #(.WIDTH(WIDTH), .hsProtocol(P4PhaseBD)) sn_input ();
    Channel #(.WIDTH(WIDTH), .hsProtocol(P4PhaseBD)) sn_output ();
    
    Channel #(.WIDTH(WIDTH), .hsProtocol(P4PhaseBD)) pe_input ();
    Channel #(.WIDTH(WIDTH), .hsProtocol(P4PhaseBD)) pe_output ();

    
    // Instantiate DUT
    async_router #(
        .FL(2),
        .BL(1),
        .WIDTH(64)
    ) dut (
        .cw_input(cw_input),
        .cw_output(cw_output),
        .ccw_input(ccw_input),
        .ccw_output(ccw_output),
        .ns_input(ns_input),
        .ns_output(ns_output),
        .sn_input(sn_input),
        .sn_output(sn_output),
        .pe_input(pe_input),
        .pe_output(pe_output)
    );
    
    
    // Monitor outputs
    data_bucket #(.WIDTH(WIDTH)) dbCW_out(.r(cw_output));
    data_bucket #(.WIDTH(WIDTH)) dbCCW_out(.r(ccw_output));
    data_bucket #(.WIDTH(WIDTH)) dbNS_out(.r(ns_output));
    data_bucket #(.WIDTH(WIDTH)) dbSN_out(.r(sn_output));
    data_bucket #(.WIDTH(WIDTH)) dbPE_out(.r(pe_output));

    task automatic build_packet_frame(
       input  logic [3:0] hx,       // X-hop count (4 bits)
       input  logic [3:0] hy,       // Y-hop count (4 bits)
       input  logic       dir_x,    // Direction X (1 bit)
       input  logic       dir_y,    // Direction Y (1 bit)
       input  logic [47:0] payload, // Payload data (48 bits)
       output logic [63:0] frame    // Final 64-bit packet
    );
       begin
          frame = 64'b0; // Clear frame
          frame[0]     = 1'b0;
          frame[4:1]   = hx;
          frame[8:5]   = hy;
          frame[9]     = dir_x;
          frame[10]    = dir_y;
          frame[15:11] = 5'b00000;
          frame[63:16] = payload;
       end
    endtask

    // Stimulus generation
    initial begin
    
      $display("\n*********************************************************************");
      $display("*                         STARTING INPUT CH STIM                      *");
      $display("*********************************************************************\n");


      // CW to CW
      #10;
      build_packet_frame(4'd1, 4'd1, 1'b0, 1'b1, 48'hAAAA_AAAA_AAAA, packet); 
      // X hop > 0, X dir = 0 (CW) => Route to CW output
      cw_input.Send(packet);

      
      // CW to SN
      #10;
      build_packet_frame(4'd0, 4'd1, 1'b1, 1'b1, 48'hBBBB_BBBB_BBBB, packet); 
      // Y hop > 0, Y dir = 1 (SN) => Route to SN output
      cw_input.Send(packet);
      
      // CW to NS
      #10;
      build_packet_frame(4'd0, 4'd1, 1'b1, 1'b0, 48'hCCCC_CCCC_CCCC, packet); 
      // Y hop > 0, Y dir = 0 (NS) => Route to NS output
      cw_input.Send(packet);
      
      // CW to PE
      #10;
      build_packet_frame(4'd0, 4'd0, 1'b0, 1'b0, 48'hDDDD_DDDD_DDDD, packet); 
      // X hop = 0, Y hop = 0 => Route to PE (local)
      cw_input.Send(packet);


      //CCW to CCW
      #10;
      build_packet_frame(4'd1, 4'd0, 1'b1, 1'b0, 48'hAAAA_AAAA_AAAA, packet); 
      // X hop > 0, dir = 1 (CCW), Y ignored
      ccw_input.Send(packet);
      
      //CCW to SN
      #10;
      build_packet_frame(4'd0, 4'd1, 1'b0, 1'b1, 48'hBBBB_BBBB_BBBB, packet); 
      // Y hop > 0, dir = 1 (SN), X ignored
      ccw_input.Send(packet);
      
      //CCW to NS
      #10;
      build_packet_frame(4'd0, 4'd1, 1'b0, 1'b0, 48'hCCCC_CCCC_CCCC, packet); 
      // Y hop > 0, dir = 0 (NS), X ignored
      ccw_input.Send(packet);
      
      //CCW to PE
      #10;
      build_packet_frame(4'd0, 4'd0, 1'b0, 1'b0, 48'hDDDD_DDDD_DDDD, packet);
      // No hops -> local (PE)
      ccw_input.Send(packet);



      // SN to SN
      #10;
      build_packet_frame(4'd0, 4'd1, 1'b0, 1'b1, 48'hAAAA_AAAA_AAAA, packet); 
      // Y hop > 0, Y dir = 1 (SN) => Route to SN output
      sn_input.Send(packet);
      
      // SN to CW
      #10;
      build_packet_frame(4'd1, 4'd0, 1'b0, 1'b0, 48'hBBBB_BBBB_BBBB, packet); 
      // X hop > 0, X dir = 0 (CW), Y hop = 0 => Route to CW output
      sn_input.Send(packet);
      
      // SN to CCW
      #10;
      build_packet_frame(4'd1, 4'd0, 1'b1, 1'b0, 48'hCCCC_CCCC_CCCC, packet); 
      // X hop > 0, X dir = 1 (CCW), Y hop = 0 => Route to CCW output
      sn_input.Send(packet);
      
      // SN to PE
      #10;
      build_packet_frame(4'd0, 4'd0, 1'b0, 1'b0, 48'hDDDD_DDDD_DDDD, packet); 
      // No hops (X hop = 0, Y hop = 0) => Route to PE (local)
      sn_input.Send(packet);



      // NS to NS
      #10;
      build_packet_frame(4'd0, 4'd1, 1'b0, 1'b0, 48'hAAAA_AAAA_AAAA, packet); 
      // Y hop > 0, Y dir = 0 (NS) => Route to NS output
      ns_input.Send(packet);
      
      // NS to CW
      #10;
      build_packet_frame(4'd1, 4'd0, 1'b0, 1'b0, 48'hBBBB_BBBB_BBBB, packet); 
      // X hop > 0, X dir = 0 (CW), Y hop = 0 => Route to CW output
      ns_input.Send(packet);
      
      // NS to CCW
      #10;
      build_packet_frame(4'd1, 4'd0, 1'b1, 1'b0, 48'hCCCC_CCCC_CCCC, packet); 
      // X hop > 0, X dir = 1 (CCW), Y hop = 0 => Route to CCW output
      ns_input.Send(packet);
      
      // NS to PE
      #10;
      build_packet_frame(4'd0, 4'd0, 1'b0, 1'b0, 48'hDDDD_DDDD_DDDD, packet); 
      // No hops (X hop = 0, Y hop = 0) => Route to PE (local)
      ns_input.Send(packet);



      // PE to CW
      #10;
      build_packet_frame(4'd1, 4'd0, 1'b0, 1'b0, 48'hAAAA_AAAA_AAAA, packet); 
      // X hop > 0, X dir = 0 (CW), Y hop = 0 => Route to CW output
      pe_input.Send(packet);
      
      // PE to CCW
      #10;
      build_packet_frame(4'd1, 4'd0, 1'b1, 1'b0, 48'hBBBB_BBBB_BBBB, packet); 
      // X hop > 0, X dir = 1 (CCW), Y hop = 0 => Route to CCW output
      pe_input.Send(packet);
      
      // PE to NS
      #10;
      build_packet_frame(4'd0, 4'd1, 1'b0, 1'b0, 48'hCCCC_CCCC_CCCC, packet); 
      // Y hop > 0, Y dir = 0 (NS), X hop = 0 => Route to NS output
      pe_input.Send(packet);
      
      // PE to SN
      #10;
      build_packet_frame(4'd0, 4'd1, 1'b0, 1'b1, 48'hDDDD_DDDD_DDDD, packet); 
      // Y hop > 0, Y dir = 1 (SN), X hop = 0 => Route to SN output
      pe_input.Send(packet);
      
      #10
      
      $display("\n*********************************************************************");
      $display("*                         STARTING ARBITRATION STIM                   *");
      $display("*********************************************************************\n");      

      build_packet_frame(4'd1, 4'd1, 1'b0, 1'b1, 48'h1111_1111_1111, packet1);
      build_packet_frame(4'd1, 4'd0, 1'b0, 1'b0, 48'h2222_2222_2222, packet2);       
      build_packet_frame(4'd1, 4'd0, 1'b0, 1'b0, 48'h3333_3333_3333, packet3); 
      build_packet_frame(4'd1, 4'd0, 1'b0, 1'b0, 48'h4444_4444_4444, packet4); 

      fork
          cw_input.Send(packet1);
          sn_input.Send(packet2);
          ns_input.Send(packet3);
          pe_input.Send(packet4);
      join
      
      #10

      $display("\n*********************************************************************");
      $display("*                         STARTING TESTING                            *");
      $display("*********************************************************************\n");   
      
      // --- CCW Output Check ---
      $display("\nChecking CCW output values...");
      for (int i = 0; i < NUM_EXPECTED; i++) begin
          if (dbCCW_out.received_data_array[i] !== expected_ccw_output[i]) begin
              $error("Mismatch at CCW[%0d]: expected %h, got %h",
                     i, expected_ccw_output[i], dbCCW_out.received_data_array[i]);
              fail_count++;
          end else begin
              $display("Match at CCW[%0d]: %h", i, dbCCW_out.received_data_array[i]);
              pass_count++;
          end
      end
      
      // --- SN Output Check ---
      $display("\nChecking SN output values...");
      for (int i = 0; i < NUM_EXPECTED; i++) begin
          if (dbSN_out.received_data_array[i] !== expected_sn_output[i]) begin
              $error("Mismatch at SN[%0d]: expected %h, got %h",
                     i, expected_sn_output[i], dbSN_out.received_data_array[i]);
              fail_count++;
          end else begin
              $display("Match at SN[%0d]: %h", i, dbSN_out.received_data_array[i]);
              pass_count++;
          end
      end
      
      // --- NS Output Check ---
      $display("\nChecking NS output values...");
      for (int i = 0; i < NUM_EXPECTED; i++) begin
          if (dbNS_out.received_data_array[i] !== expected_ns_output[i]) begin
              $error("Mismatch at NS[%0d]: expected %h, got %h",
                     i, expected_ns_output[i], dbNS_out.received_data_array[i]);
              fail_count++;
          end else begin
              $display("Match at NS[%0d]: %h", i, dbNS_out.received_data_array[i]);
              pass_count++;
          end
      end
      
      // --- PE Output Check ---
      $display("\nChecking PE output values...");
      for (int i = 0; i < NUM_EXPECTED; i++) begin
          if (dbPE_out.received_data_array[i] !== expected_pe_output[i]) begin
              $error("Mismatch at PE[%0d]: expected %h, got %h",
                     i, expected_pe_output[i], dbPE_out.received_data_array[i]);
              fail_count++;
          end else begin
              $display("Match at PE[%0d]: %h", i, dbPE_out.received_data_array[i]);
              pass_count++;
          end
      end
      
      $display("\n*********************************************************************");
      $display("Test Summary: PASS = %0d, FAIL = %0d", pass_count, fail_count);
      $display("Note sim check for ARBITER TEST");
      $display("*********************************************************************\n");

      

      #20;
      $stop;
    end
    
endmodule
