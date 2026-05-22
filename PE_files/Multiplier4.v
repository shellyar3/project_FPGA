module Multiplier4(
    input signed [3:0] a,
    input signed [3:0] b,
    input a_signed,
    input b_signed,
    output signed [8:0] mult4out
);

wire signed [4:0] signed_a = (a_signed) ? {a[3], a} : {1'b0, a};
wire signed [4:0] signed_b = (b_signed) ? {b[3], b} : {1'b0, b};

wire signed [9:0] product = signed_a * signed_b;

assign mult4out = product[8:0];

endmodule