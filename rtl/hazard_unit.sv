// Load-use detection. If the instruction in EX is a load and the one in ID
// needs its result, hold PC and IF/ID for one cycle and send a bubble into EX.
//
// TODO: this compares rs2 even for I-type / U-type / J-type instructions that
// don't read rs2, so it occasionally stalls when it doesn't need to.

module hazard_unit (
  input  logic       idex_mem_read,
  input  logic [4:0] idex_rd,
  input  logic [4:0] ifid_rs1,
  input  logic [4:0] ifid_rs2,
  output logic       stall
);

  assign stall = idex_mem_read && (idex_rd != 5'd0) &&
                 ((idex_rd == ifid_rs1) || (idex_rd == ifid_rs2));

endmodule
