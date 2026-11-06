// 32 x 32 register file, 2 read ports / 1 write port.
// Reads are combinational. If WB writes the same register ID is reading in
// the same cycle, the new value is passed straight through (write-before-read),
// so there's no need for a third forwarding path from WB into ID.

module regfile (
  input  logic        clk,
  input  logic        we,
  input  logic [4:0]  waddr,
  input  logic [31:0] wdata,
  input  logic [4:0]  raddr1,
  input  logic [4:0]  raddr2,
  output logic [31:0] rdata1,
  output logic [31:0] rdata2
);

  logic [31:0] regs [0:31];

  initial begin
    for (int i = 0; i < 32; i++) regs[i] = 32'b0;
  end

  always_ff @(posedge clk) begin
    if (we && waddr != 5'd0)
      regs[waddr] <= wdata;
  end

  assign rdata1 = (raddr1 == 5'd0)                ? 32'b0 :
                  (we && waddr == raddr1)         ? wdata : regs[raddr1];

  assign rdata2 = (raddr2 == 5'd0)                ? 32'b0 :
                  (we && waddr == raddr2)         ? wdata : regs[raddr2];

endmodule
