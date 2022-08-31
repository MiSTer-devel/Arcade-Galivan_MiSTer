
module video(
  input clk,
  output reg hs,
  output reg vs,
  output reg hb,
  output reg vb,
  output reg [8:0] hcount,
  output reg [8:0] vcount,
  output reg frame,
  input [4:0] hoffs,
  input [2:0] voffs
);

initial begin
  hs <= 1'b1;
  vs <= 1'b1;
end

always @(posedge clk) begin
  frame <= 1'b0;
  hcount <= hcount + 9'd1;
  case (hcount)
    1: hb <= 1'b0;
    256: hb <= 1'b1;
    271: hs <= 1'b0;
    295: hs <= 1'b1;
    335-hoffs: begin
      vcount <= vcount + 9'd1;
      hcount <= 9'b0;
      case (vcount)
         15: vb <= 1'b0;
        239: vb <= 1'b1;
        249: vs <= 1'b0;
        252: vs <= 1'b1;
        272+voffs: vcount <= 9'd0;
      endcase
    end
  endcase
end

endmodule
