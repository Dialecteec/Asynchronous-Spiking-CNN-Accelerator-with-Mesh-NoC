`timescale 1ns/1ps

module full_adder (
    input   x,  // Input x
    input   y,  // Input y
    input   ci, // Carry-in
    output  s,  // Sum output
    output  co  // Carry-out
);

// Using gate-level descriptions
// s = x ^ y ^ ci
// co = (x & y) | (x & ci) | (y & ci)
    wire x_xor_y;
    wire x_and_y;
    wire x_and_ci;
    wire y_and_ci;

    xor (x_xor_y, x, y);
    xor (s, x_xor_y, ci);
    and (x_and_y,  x,  y);
    and (x_and_ci, x,  ci);
    and (y_and_ci, y,  ci);
    or  (co, x_and_y, x_and_ci, y_and_ci);

endmodule

module adder_gate#(
    parameter WIDTH	= 8
) (
    input   [WIDTH-1:0] opA, // input opA
    input   [WIDTH-1:0] opB, // input opB
    output  [WIDTH:0] sum    // output sum
);

    logic [WIDTH-1:0] carry;  // Intermediate carry signals

    genvar i;  // Generate variable for instantiating the full adders
    // Generate block to instantiate a chain of full adders
    generate for (i = 0; i < WIDTH; i++) begin: adder_chain
            // First bit: No carry-in for the least significant bit
            // For the rest of the bits: carry-in comes from the previous stage
             full_adder FA (
                .x(opA[i]),
                .y(opB[i]),
                .ci((i == 0) ? 1'b0 : carry[i-1]),
                .s(sum[i]),
                .co(carry[i])
            );
    end
    endgenerate
    // Final carry-out ( MSB of the output ) is the carry from the most significant bit (MSB)
    assign sum[WIDTH] = carry[WIDTH-1];

endmodule

