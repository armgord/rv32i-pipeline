// Data memory: synchronous write, combinational read.
// TODO: only full-word access right now. LB/LH/LBU/LHU/SB/SH need byte
// enables + sign/zero extension using funct3 (already passed down to MEM).

module dmem #(
  parameter int WORDS = 1024
) (
  input  logic        clk,
  input  logic        we,
  input  logic [31:0] addr,
  input  logic [31:0] wdata,
  output logic [31:0] rdata
);

  localparam int AW = $clog2(WORDS);

  logic [31:0] mem [0:WORDS-1];

  initial begin
    for (int i = 0; i < WORDS; i++) mem[i] = 32'b0;
  end

  always_ff @(posedge clk) begin
    if (we)
      mem[addr[AW+1:2]] <= wdata;
  end

  assign rdata = mem[addr[AW+1:2]];

endmodule
