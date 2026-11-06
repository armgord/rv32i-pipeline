// Instruction memory: word-addressed, combinational read.
// Contents are loaded by the testbench with $readmemh.

module imem #(
  parameter int WORDS = 1024
) (
  input  logic [31:0] addr,
  output logic [31:0] instr
);

  localparam int AW = $clog2(WORDS);

  logic [31:0] mem [0:WORDS-1];

  assign instr = mem[addr[AW+1:2]];

endmodule
