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

module mesh_tb ();

    // Parameter definitions
    parameter WIDTH = 64;
    parameter FL = 0;
    parameter BL = 0;
    
    
    logic [47:0] expected_output [0:9] = '{
    48'hAAAA_AAAA_AAAA,
    48'hBBBB_BBBB_BBBB,
    48'hCCCC_CCCC_CCCC,
    48'hDDDD_DDDD_DDDD,
    48'hEEEE_EEEE_EEEE,
    48'h1111_1111_1111,
    48'h2222_2222_2222,
    48'h3333_3333_3333,
    48'h4444_4444_4444,
    48'h5555_5555_5555
    };

    localparam int NUM_EXPECTED = 10;
    int fail_count;
    int pass_count;
    bit matched_indices[NUM_EXPECTED];
    bit found;

    logic [WIDTH-1:0] packet;
    logic [WIDTH-1:0] packet1;
    logic [WIDTH-1:0] packet2;
    logic [WIDTH-1:0] packet3;
    logic [WIDTH-1:0] packet4;
    logic [WIDTH-1:0] packet5;

    // External Input/Output Channel Interfaces
    Channel #(.WIDTH(WIDTH), .hsProtocol(P4PhaseBD)) pe_input_00 ();
    Channel #(.WIDTH(WIDTH), .hsProtocol(P4PhaseBD)) pe_output_00 ();
    
    Channel #(.WIDTH(WIDTH), .hsProtocol(P4PhaseBD)) pe_input_01 ();
    Channel #(.WIDTH(WIDTH), .hsProtocol(P4PhaseBD)) pe_output_01 ();
    
    Channel #(.WIDTH(WIDTH), .hsProtocol(P4PhaseBD)) pe_input_02 ();
    Channel #(.WIDTH(WIDTH), .hsProtocol(P4PhaseBD)) pe_output_02 ();
    
    Channel #(.WIDTH(WIDTH), .hsProtocol(P4PhaseBD)) pe_input_10 ();
    Channel #(.WIDTH(WIDTH), .hsProtocol(P4PhaseBD)) pe_output_10 ();
    
    Channel #(.WIDTH(WIDTH), .hsProtocol(P4PhaseBD)) pe_input_11 ();
    Channel #(.WIDTH(WIDTH), .hsProtocol(P4PhaseBD)) pe_output_11 ();
    
    Channel #(.WIDTH(WIDTH), .hsProtocol(P4PhaseBD)) pe_input_12 ();
    Channel #(.WIDTH(WIDTH), .hsProtocol(P4PhaseBD)) pe_output_12 ();

    
    // Instantiate DUT
    mesh #(
       .FL(FL),
       .BL(BL),
       .WIDTH(WIDTH)
    ) mesh_inst (
       .pe_input_00(pe_input_00),
       .pe_output_00(pe_output_00),
       
       .pe_input_01(pe_input_01),
       .pe_output_01(pe_output_01),
       
       .pe_input_02(pe_input_02),
       .pe_output_02(pe_output_02),
       
       .pe_input_10(pe_input_10),
       .pe_output_10(pe_output_10),
       
       .pe_input_11(pe_input_11),
       .pe_output_11(pe_output_11),
       
       .pe_input_12(pe_input_12),
       .pe_output_12(pe_output_12)
    );
    
    
    // Monitor outputs
    data_bucket #(.WIDTH(WIDTH)) db_pe_output_00(.r(pe_output_00));
    data_bucket #(.WIDTH(WIDTH)) db_pe_output_01(.r(pe_output_01));
    data_bucket #(.WIDTH(WIDTH)) db_pe_output_02(.r(pe_output_02));
    data_bucket #(.WIDTH(WIDTH)) db_pe_output_10(.r(pe_output_10));
    data_bucket #(.WIDTH(WIDTH)) db_pe_output_11(.r(pe_output_11));
    data_bucket #(.WIDTH(WIDTH)) db_pe_output_12(.r(pe_output_12));

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
      $display("*           STARTING TEST: ALL NODES SENDING DATA TO NODE (0,0)       *");
      $display("*           EXCLUDING NODE (0,0) ITSELF FROM TRANSMISSION             *");
      $display("*********************************************************************\n");


      // From 01 to 00 => X hop = 1, X dir = 1 (CCW)
      #10;
      build_packet_frame(4'd1, 4'd0, 1'b1, 1'b0, 48'hAAAA_AAAA_AAAA, packet); 
      pe_input_01.Send(packet);
      
      // From 02 to 00 => X hop = 2, X dir = 1 (CCW)
      #10;
      build_packet_frame(4'd2, 4'd0, 1'b1, 1'b0, 48'hBBBB_BBBB_BBBB, packet); 
      pe_input_02.Send(packet);
      
      // From 10 to 00 => Y hop = 1, Y dir = 1 (SN)
      #10;
      build_packet_frame(4'd0, 4'd1, 1'b0, 1'b1, 48'hCCCC_CCCC_CCCC, packet); 
      pe_input_10.Send(packet);
      
      // From 11 to 00 => X hop = 1, X dir = 1 (CCW), Y hop = 1, Y dir = 1 (SN)
      #10;
      build_packet_frame(4'd1, 4'd1, 1'b1, 1'b1, 48'hDDDD_DDDD_DDDD, packet); 
      pe_input_11.Send(packet);
      
      // From 12 to 00 => => X hop = 2, X dir = 1 (CCW), Y hop = 1, Y dir = 1 (SN)
      #10;
      build_packet_frame(4'd2, 4'd1, 1'b1, 1'b1, 48'hEEEE_EEEE_EEEE, packet); 
      pe_input_12.Send(packet);

      #10
      
      // From 01 to 00 => X hop = 1, X dir = 1 (CCW)
      build_packet_frame(4'd1, 4'd0, 1'b1, 1'b0, 48'h1111_1111_1111, packet1); 

      // From 02 to 00 => X hop = 2, X dir = 1 (CCW)
      build_packet_frame(4'd2, 4'd0, 1'b1, 1'b0, 48'h2222_2222_2222, packet2); 

      // From 10 to 00 => Y hop = 1, Y dir = 1 (SN)
      build_packet_frame(4'd0, 4'd1, 1'b0, 1'b1, 48'h3333_3333_3333, packet3); 

      // From 11 to 00 => X hop = 1, X dir = 1 (CCW), Y hop = 1, Y dir = 1 (SN)
      build_packet_frame(4'd1, 4'd1, 1'b1, 1'b1, 48'h4444_4444_4444, packet4); 

      // From 12 to 00 => => X hop = 2, X dir = 1 (CCW), Y hop = 1, Y dir = 1 (SN)
      build_packet_frame(4'd2, 4'd1, 1'b1, 1'b1, 48'h5555_5555_5555, packet5); 
      
      
      //Inject pakages concurrently 
      fork
         pe_input_01.Send(packet1);
         pe_input_02.Send(packet2);
         pe_input_10.Send(packet3);
         pe_input_11.Send(packet4);
         pe_input_12.Send(packet5);

      join


      $display("\n*********************************************************************");
      $display("*           STARTING TEST: ALL NODES SENDING DATA TO NODE (0,1)       *");
      $display("*           EXCLUDING NODE (0,1) ITSELF FROM TRANSMISSION             *");
      $display("*********************************************************************\n");


      // From 00 to 01 => X hop = 1, X dir = 0 (CW)
      #10;
      build_packet_frame(4'd1, 4'd0, 1'b0, 1'b0, 48'hAAAA_AAAA_AAAA, packet); 
      pe_input_00.Send(packet);
      
      // From 02 to 01 => X hop = 1, X dir = 1 (CCW)
      #10;
      build_packet_frame(4'd1, 4'd0, 1'b1, 1'b0, 48'hBBBB_BBBB_BBBB, packet); 
      pe_input_02.Send(packet);
      
      // From 10 to 01 => X hop = 1 , X dir = 0 (CW), Y hop = 1, Y dir = 1 (SN)
      #10;
      build_packet_frame(4'd1, 4'd1, 1'b0, 1'b1, 48'hCCCC_CCCC_CCCC, packet); 
      pe_input_10.Send(packet);
      
      // From 11 to 01 => X hop = 0, Y hop = 1, Y dir = 1 (SN)
      #10;
      build_packet_frame(4'd0, 4'd1, 1'b0, 1'b1, 48'hDDDD_DDDD_DDDD, packet); 
      pe_input_11.Send(packet);
      
      // From 12 to 01 => X hop = 1, X dir = 1 (CCW), Y dir = 1 (SN)
      #10;
      build_packet_frame(4'd1, 4'd1, 1'b1, 1'b1, 48'hEEEE_EEEE_EEEE, packet); 
      pe_input_12.Send(packet);
      
      #10
      
      // Prepare for concurrent send
      build_packet_frame(4'd1, 4'd0, 1'b0, 1'b0, 48'h1111_1111_1111, packet1); 
      build_packet_frame(4'd1, 4'd0, 1'b1, 1'b0, 48'h2222_2222_2222, packet2); 
      build_packet_frame(4'd1, 4'd1, 1'b0, 1'b1, 48'h3333_3333_3333, packet3); 
      build_packet_frame(4'd0, 4'd1, 1'b0, 1'b1, 48'h4444_4444_4444, packet4); 
      build_packet_frame(4'd1, 4'd1, 1'b1, 1'b1, 48'h5555_5555_5555, packet5); 
      
      // Inject packets concurrently
      fork
         pe_input_00.Send(packet1);
         pe_input_02.Send(packet2);
         pe_input_10.Send(packet3);
         pe_input_11.Send(packet4);
         pe_input_12.Send(packet5);
      join


      $display("\n*********************************************************************");
      $display("*           STARTING TEST: ALL NODES SENDING DATA TO NODE (0,2)       *");
      $display("*           EXCLUDING NODE (0,2) ITSELF FROM TRANSMISSION             *");
      $display("*********************************************************************\n");
      
      // From 00 to 02 => X hop = 2, X dir = 0 (CW)
      #10;
      build_packet_frame(4'd2, 4'd0, 1'b0, 1'b0, 48'hAAAA_AAAA_AAAA, packet); 
      pe_input_00.Send(packet);
      
      // From 01 to 02 => X hop = 1, X dir = 0 (CW)
      #10;
      build_packet_frame(4'd1, 4'd0, 1'b0, 1'b0, 48'hBBBB_BBBB_BBBB, packet); 
      pe_input_01.Send(packet);
      
      // From 10 to 02 => X hop = 2, X dir = 0 (CW), Y hop = 1, Y dir = 1 (SN)
      #10;
      build_packet_frame(4'd2, 4'd1, 1'b0, 1'b1, 48'hCCCC_CCCC_CCCC, packet); 
      pe_input_10.Send(packet);
      
      // From 11 to 02 => X hop = 1, X dir = 0 (CW), Y hop = 1, Y dir = 1 (SN)
      #10;
      build_packet_frame(4'd1, 4'd1, 1'b0, 1'b1, 48'hDDDD_DDDD_DDDD, packet); 
      pe_input_11.Send(packet);
      
      // From 12 to 02 => X hop = 0, Y hop = 1, Y dir = 1 (SN)
      #10;
      build_packet_frame(4'd0, 4'd1, 1'b0, 1'b1, 48'hEEEE_EEEE_EEEE, packet); 
      pe_input_12.Send(packet);
      
      #10
      
      // Prepare for concurrent send
      build_packet_frame(4'd2, 4'd0, 1'b0, 1'b0, 48'h1111_1111_1111, packet1); 
      build_packet_frame(4'd1, 4'd0, 1'b0, 1'b0, 48'h2222_2222_2222, packet2); 
      build_packet_frame(4'd2, 4'd1, 1'b0, 1'b1, 48'h3333_3333_3333, packet3); 
      build_packet_frame(4'd1, 4'd1, 1'b0, 1'b1, 48'h4444_4444_4444, packet4); 
      build_packet_frame(4'd0, 4'd1, 1'b0, 1'b1, 48'h5555_5555_5555, packet5); 
      
      // Inject packets concurrently
      fork
         pe_input_00.Send(packet1);
         pe_input_01.Send(packet2);
         pe_input_10.Send(packet3);
         pe_input_11.Send(packet4);
         pe_input_12.Send(packet5);
      join


      $display("\n*********************************************************************");
      $display("*           STARTING TEST: ALL NODES SENDING DATA TO NODE (1,0)       *");
      $display("*           EXCLUDING NODE (1,0) ITSELF FROM TRANSMISSION             *");
      $display("*********************************************************************\n");
      
      // From 00 to 10 => X hop = 0, Y hop = 1, Y dir = 0 (NS)
      #10;
      build_packet_frame(4'd0, 4'd1, 1'b0, 1'b0, 48'hAAAA_AAAA_AAAA, packet); 
      pe_input_00.Send(packet);
      
      // From 01 to 10 => X hop = 1, X dir = 1 (CCW), Y hop = 1, Y dir = 0 (NS)
      #10;
      build_packet_frame(4'd1, 4'd1, 1'b1, 1'b0, 48'hBBBB_BBBB_BBBB, packet); 
      pe_input_01.Send(packet);
      
      // From 02 to 10 => X hop = 2, X dir = 1 (CCW), Y hop = 1, Y dir = 0 (NS)
      #10;
      build_packet_frame(4'd2, 4'd1, 1'b1, 1'b0, 48'hCCCC_CCCC_CCCC, packet); 
      pe_input_02.Send(packet);
      
      // From 11 to 10 => X hop = 1, X dir = 1 (CCW)
      #10;
      build_packet_frame(4'd1, 4'd0, 1'b1, 1'b0, 48'hDDDD_DDDD_DDDD, packet); 
      pe_input_11.Send(packet);
      
      // From 12 to 10 => X hop = 2, X dir = 1 (CCW)
      #10;
      build_packet_frame(4'd2, 4'd0, 1'b1, 1'b0, 48'hEEEE_EEEE_EEEE, packet); 
      pe_input_12.Send(packet);
      
      #10
      
      // Prepare for concurrent send
      build_packet_frame(4'd0, 4'd1, 1'b0, 1'b0, 48'h1111_1111_1111, packet1); 
      build_packet_frame(4'd1, 4'd1, 1'b1, 1'b0, 48'h2222_2222_2222, packet2); 
      build_packet_frame(4'd2, 4'd1, 1'b1, 1'b0, 48'h3333_3333_3333, packet3); 
      build_packet_frame(4'd1, 4'd0, 1'b1, 1'b0, 48'h4444_4444_4444, packet4); 
      build_packet_frame(4'd2, 4'd0, 1'b1, 1'b0, 48'h5555_5555_5555, packet5); 
      
      // Inject packets concurrently
      fork
         pe_input_00.Send(packet1);
         pe_input_01.Send(packet2);
         pe_input_02.Send(packet3);
         pe_input_11.Send(packet4);
         pe_input_12.Send(packet5);
      join


      $display("\n*********************************************************************");
      $display("*           STARTING TEST: ALL NODES SENDING DATA TO NODE (1,1)       *");
      $display("*           EXCLUDING NODE (1,1) ITSELF FROM TRANSMISSION             *");
      $display("*********************************************************************\n");
      
      // From 00 to 11 => X hop = 1, X dir = 0 (CW), Y hop = 1, Y dir = 0 (NS)
      #10;
      build_packet_frame(4'd1, 4'd1, 1'b0, 1'b0, 48'hAAAA_AAAA_AAAA, packet); 
      pe_input_00.Send(packet);
      
      // From 01 to 11 => X hop = 0, Y hop = 1, Y dir = 0 (NS)
      #10;
      build_packet_frame(4'd0, 4'd1, 1'b0, 1'b0, 48'hBBBB_BBBB_BBBB, packet); 
      pe_input_01.Send(packet);
      
      // From 02 to 11 => X hop = 1, X dir = 1 (CCW), Y hop = 1, Y dir = 0 (NS)
      #10;
      build_packet_frame(4'd1, 4'd1, 1'b1, 1'b0, 48'hCCCC_CCCC_CCCC, packet); 
      pe_input_02.Send(packet);
      
      // From 10 to 11 => X hop = 1, X dir = 0 (CW)
      #10;
      build_packet_frame(4'd1, 4'd0, 1'b0, 1'b0, 48'hDDDD_DDDD_DDDD, packet); 
      pe_input_10.Send(packet);
      
      // From 12 to 11 => X hop = 1, X dir = 1 (CCW)
      #10;
      build_packet_frame(4'd1, 4'd0, 1'b1, 1'b0, 48'hEEEE_EEEE_EEEE, packet); 
      pe_input_12.Send(packet);
      
      #10
      
      // Prepare for concurrent send
      build_packet_frame(4'd1, 4'd1, 1'b0, 1'b0, 48'h1111_1111_1111, packet1);
      build_packet_frame(4'd0, 4'd1, 1'b0, 1'b0, 48'h2222_2222_2222, packet2);
      build_packet_frame(4'd1, 4'd1, 1'b1, 1'b0, 48'h3333_3333_3333, packet3);
      build_packet_frame(4'd1, 4'd0, 1'b0, 1'b0, 48'h4444_4444_4444, packet4);
      build_packet_frame(4'd1, 4'd0, 1'b1, 1'b0, 48'h5555_5555_5555, packet5);
      
      // Inject packets concurrently
      fork
         pe_input_00.Send(packet1);
         pe_input_01.Send(packet2);
         pe_input_02.Send(packet3);
         pe_input_10.Send(packet4);
         pe_input_12.Send(packet5);
      join


      $display("\n*********************************************************************");
      $display("*           STARTING TEST: ALL NODES SENDING DATA TO NODE (1,2)       *");
      $display("*           EXCLUDING NODE (1,2) ITSELF FROM TRANSMISSION             *");
      $display("*********************************************************************\n");
      
      // From 00 to 12 => X hop = 2, X dir = 0 (CW), Y hop = 1, Y dir = 0 (NS)
      #10;
      build_packet_frame(4'd2, 4'd1, 1'b0, 1'b0, 48'hAAAA_AAAA_AAAA, packet); 
      pe_input_00.Send(packet);
      
      // From 01 to 12 => X hop = 1, X dir = 0 (CW), Y hop = 1, Y dir = 0 (NS)
      #10;
      build_packet_frame(4'd1, 4'd1, 1'b0, 1'b0, 48'hBBBB_BBBB_BBBB, packet); 
      pe_input_01.Send(packet);
      
      // From 02 to 12 => X hop = 0, Y hop = 1, Y dir = 0 (NS)
      #10;
      build_packet_frame(4'd0, 4'd1, 1'b0, 1'b0, 48'hCCCC_CCCC_CCCC, packet); 
      pe_input_02.Send(packet);
      
      // From 10 to 12 => X hop = 2, X dir = 0 (CW)
      #10;
      build_packet_frame(4'd2, 4'd0, 1'b0, 1'b0, 48'hDDDD_DDDD_DDDD, packet); 
      pe_input_10.Send(packet);
      
      // From 11 to 12 => X hop = 1, X dir = 0 (CW)
      #10;
      build_packet_frame(4'd1, 4'd0, 1'b0, 1'b0, 48'hEEEE_EEEE_EEEE, packet); 
      pe_input_11.Send(packet);
      
      #10
      
      // Prepare for concurrent send
      build_packet_frame(4'd2, 4'd1, 1'b0, 1'b0, 48'h1111_1111_1111, packet1); // 00
      build_packet_frame(4'd1, 4'd1, 1'b0, 1'b0, 48'h2222_2222_2222, packet2); // 01
      build_packet_frame(4'd0, 4'd1, 1'b0, 1'b0, 48'h3333_3333_3333, packet3); // 02
      build_packet_frame(4'd2, 4'd0, 1'b0, 1'b0, 48'h4444_4444_4444, packet4); // 10
      build_packet_frame(4'd1, 4'd0, 1'b0, 1'b0, 48'h5555_5555_5555, packet5); // 11
      
      // Inject packets concurrently
      fork
         pe_input_00.Send(packet1);
         pe_input_01.Send(packet2);
         pe_input_02.Send(packet3);
         pe_input_10.Send(packet4);
         pe_input_11.Send(packet5);
      join


      #10
      $display("\n*********************************************************************");
      $display("*                         STARTING TESTING                            *");
      $display("*********************************************************************\n");   
      
      $display("\nChecking PE 00 output values...");


      for (int i = 0; i < NUM_EXPECTED; i++) matched_indices[i] = 0;
      
      for (int i = 0; i < NUM_EXPECTED; i++) begin
          found = 0;
          for (int j = 0; j < NUM_EXPECTED; j++) begin
              if (!matched_indices[j] && db_pe_output_00.received_data_array[i] === expected_output[j]) begin
                  $display("Match found: received %h matches expected[%0d]", 
                           db_pe_output_00.received_data_array[i], j);
                  matched_indices[j] = 1;
                  pass_count++;
                  found = 1;
                  break;
              end
          end
          if (!found) begin
              $error("Unexpected value at CCW[%0d]: got %h", 
                     i, db_pe_output_00.received_data_array[i]);
              fail_count++;
          end
      end
      
      // Check for any missing expected values
      for (int j = 0; j < NUM_EXPECTED; j++) begin
          if (!matched_indices[j]) begin
              $error("Missing expected value: %h", expected_output[j]);
              fail_count++;
          end
      end
      
      
      $display("\nChecking PE 01 output values...");

      for (int i = 0; i < NUM_EXPECTED; i++) matched_indices[i] = 0;
      
      for (int i = 0; i < NUM_EXPECTED; i++) begin
          found = 0;
          for (int j = 0; j < NUM_EXPECTED; j++) begin
              if (!matched_indices[j] && db_pe_output_01.received_data_array[i] === expected_output[j]) begin
                  $display("Match found: received %h matches expected[%0d]", 
                           db_pe_output_01.received_data_array[i], j);
                  matched_indices[j] = 1;
                  pass_count++;
                  found = 1;
                  break;
              end
          end
          if (!found) begin
              $error("Unexpected value at CCW[%0d]: got %h", 
                     i, db_pe_output_01.received_data_array[i]);
              fail_count++;
          end
      end
      
      // Check for any missing expected values
      for (int j = 0; j < NUM_EXPECTED; j++) begin
          if (!matched_indices[j]) begin
              $error("Missing expected value: %h", expected_output[j]);
              fail_count++;
          end
      end
      
      
      $display("\nChecking PE 02 output values...");

      for (int i = 0; i < NUM_EXPECTED; i++) matched_indices[i] = 0;
      
      for (int i = 0; i < NUM_EXPECTED; i++) begin
          found = 0;
          for (int j = 0; j < NUM_EXPECTED; j++) begin
              if (!matched_indices[j] && db_pe_output_02.received_data_array[i] === expected_output[j]) begin
                  $display("Match found: received %h matches expected[%0d]", 
                           db_pe_output_02.received_data_array[i], j);
                  matched_indices[j] = 1;
                  pass_count++;
                  found = 1;
                  break;
              end
          end
          if (!found) begin
              $error("Unexpected value at CCW[%0d]: got %h", 
                     i, db_pe_output_02.received_data_array[i]);
              fail_count++;
          end
      end
      
      // Check for any missing expected values
      for (int j = 0; j < NUM_EXPECTED; j++) begin
          if (!matched_indices[j]) begin
              $error("Missing expected value: %h", expected_output[j]);
              fail_count++;
          end
      end
      
      $display("\nChecking PE 10 output values...");

      for (int i = 0; i < NUM_EXPECTED; i++) matched_indices[i] = 0;
      
      for (int i = 0; i < NUM_EXPECTED; i++) begin
          found = 0;
          for (int j = 0; j < NUM_EXPECTED; j++) begin
              if (!matched_indices[j] && db_pe_output_10.received_data_array[i] === expected_output[j]) begin
                  $display("Match found: received %h matches expected[%0d]", 
                           db_pe_output_10.received_data_array[i], j);
                  matched_indices[j] = 1;
                  pass_count++;
                  found = 1;
                  break;
              end
          end
          if (!found) begin
              $error("Unexpected value at CCW[%0d]: got %h", 
                     i, db_pe_output_10.received_data_array[i]);
              fail_count++;
          end
      end
      
      // Check for any missing expected values
      for (int j = 0; j < NUM_EXPECTED; j++) begin
          if (!matched_indices[j]) begin
              $error("Missing expected value: %h", expected_output[j]);
              fail_count++;
          end
      end
      
      $display("\nChecking PE 11 output values...");

      for (int i = 0; i < NUM_EXPECTED; i++) matched_indices[i] = 0;
      
      for (int i = 0; i < NUM_EXPECTED; i++) begin
          found = 0;
          for (int j = 0; j < NUM_EXPECTED; j++) begin
              if (!matched_indices[j] && db_pe_output_11.received_data_array[i] === expected_output[j]) begin
                  $display("Match found: received %h matches expected[%0d]", 
                           db_pe_output_11.received_data_array[i], j);
                  matched_indices[j] = 1;
                  pass_count++;
                  found = 1;
                  break;
              end
          end
          if (!found) begin
              $error("Unexpected value at CCW[%0d]: got %h", 
                     i, db_pe_output_11.received_data_array[i]);
              fail_count++;
          end
      end
      
      // Check for any missing expected values
      for (int j = 0; j < NUM_EXPECTED; j++) begin
          if (!matched_indices[j]) begin
              $error("Missing expected value: %h", expected_output[j]);
              fail_count++;
          end
      end
      
      $display("\nChecking PE 12 output values...");

      for (int i = 0; i < NUM_EXPECTED; i++) matched_indices[i] = 0;
      
      for (int i = 0; i < NUM_EXPECTED; i++) begin
          found = 0;
          for (int j = 0; j < NUM_EXPECTED; j++) begin
              if (!matched_indices[j] && db_pe_output_12.received_data_array[i] === expected_output[j]) begin
                  $display("Match found: received %h matches expected[%0d]", 
                           db_pe_output_12.received_data_array[i], j);
                  matched_indices[j] = 1;
                  pass_count++;
                  found = 1;
                  break;
              end
          end
          if (!found) begin
              $error("Unexpected value at CCW[%0d]: got %h", 
                     i, db_pe_output_12.received_data_array[i]);
              fail_count++;
          end
      end
      
      // Check for any missing expected values
      for (int j = 0; j < NUM_EXPECTED; j++) begin
          if (!matched_indices[j]) begin
              $error("Missing expected value: %h", expected_output[j]);
              fail_count++;
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
