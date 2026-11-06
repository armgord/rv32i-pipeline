// Main decoder. Everything not listed below decodes as a NOP for now
// (FENCE, ECALL/EBREAK, CSR instructions) -- see TODO in README.

module control
  import riscv_pkg::*;
(
  input  logic [31:0] instr,
  output logic        reg_write,
  output logic        mem_read,
  output logic        mem_write,
  output logic        branch,
  output logic        jal,
  output logic        jalr,
  output logic        alu_a_pc,    // ALU A input = PC (AUIPC)
  output logic        alu_b_imm,   // ALU B input = immediate
  output alu_op_t     alu_op,
  output wb_sel_t     wb_sel
);

  logic [6:0] opcode;
  logic [2:0] funct3;
  logic       funct7_5;            // instr[30]: SUB / SRA / SRAI
  alu_op_t    arith_op;

  assign opcode   = instr[6:0];
  assign funct3   = instr[14:12];
  assign funct7_5 = instr[30];

  // ALU op for OP and OP-IMM. Only R-type uses bit 30 for SUB,
  // since in ADDI that bit is part of the immediate.
  always_comb begin
    case (funct3)
      3'b000:  if (opcode == OP_REG && funct7_5) arith_op = ALU_SUB;
               else                             arith_op = ALU_ADD;
      3'b001:  arith_op = ALU_SLL;
      3'b010:  arith_op = ALU_SLT;
      3'b011:  arith_op = ALU_SLTU;
      3'b100:  arith_op = ALU_XOR;
      3'b101:  if (funct7_5) arith_op = ALU_SRA;
               else          arith_op = ALU_SRL;
      3'b110:  arith_op = ALU_OR;
      default: arith_op = ALU_AND;
    endcase
  end

  always_comb begin
    reg_write = 1'b0;
    mem_read  = 1'b0;
    mem_write = 1'b0;
    branch    = 1'b0;
    jal       = 1'b0;
    jalr      = 1'b0;
    alu_a_pc  = 1'b0;
    alu_b_imm = 1'b0;
    alu_op    = ALU_ADD;
    wb_sel    = WB_ALU;

    case (opcode)
      OP_REG: begin
        reg_write = 1'b1;
        alu_op    = arith_op;
      end
      OP_IMM: begin
        reg_write = 1'b1;
        alu_b_imm = 1'b1;
        alu_op    = arith_op;
      end
      OP_LOAD: begin
        reg_write = 1'b1;
        mem_read  = 1'b1;
        alu_b_imm = 1'b1;
        wb_sel    = WB_MEM;
      end
      OP_STORE: begin
        mem_write = 1'b1;
        alu_b_imm = 1'b1;
      end
      OP_BRANCH: begin
        branch = 1'b1;
      end
      OP_LUI: begin
        reg_write = 1'b1;
        alu_b_imm = 1'b1;
        alu_op    = ALU_PASSB;
      end
      OP_AUIPC: begin
        reg_write = 1'b1;
        alu_a_pc  = 1'b1;
        alu_b_imm = 1'b1;
      end
      OP_JAL: begin
        reg_write = 1'b1;
        jal       = 1'b1;
        wb_sel    = WB_PC4;
      end
      OP_JALR: begin
        reg_write = 1'b1;
        jalr      = 1'b1;
        alu_b_imm = 1'b1;           // ALU computes rs1 + imm = target
        wb_sel    = WB_PC4;
      end
      default: ;                    // TODO: FENCE, ECALL/EBREAK, Zicsr
    endcase
  end

endmodule
