// Selects where EX gets its rs1/rs2 operands from:
//   2'b00 = value read from the register file in ID
//   2'b10 = EX/MEM result (instruction one ahead)
//   2'b01 = MEM/WB result (instruction two ahead)
// EX/MEM has priority because it is the more recent write.

module forwarding_unit (
  input  logic [4:0] idex_rs1,
  input  logic [4:0] idex_rs2,
  input  logic       exmem_reg_write,
  input  logic [4:0] exmem_rd,
  input  logic       memwb_reg_write,
  input  logic [4:0] memwb_rd,
  output logic [1:0] fwd_a,
  output logic [1:0] fwd_b
);

  always_comb begin
    fwd_a = 2'b00;
    if (exmem_reg_write && exmem_rd != 5'd0 && exmem_rd == idex_rs1)
      fwd_a = 2'b10;
    else if (memwb_reg_write && memwb_rd != 5'd0 && memwb_rd == idex_rs1)
      fwd_a = 2'b01;

    fwd_b = 2'b00;
    if (exmem_reg_write && exmem_rd != 5'd0 && exmem_rd == idex_rs2)
      fwd_b = 2'b10;
    else if (memwb_reg_write && memwb_rd != 5'd0 && memwb_rd == idex_rs2)
      fwd_b = 2'b01;
  end

endmodule
