// Shared definitions for the RV32I core

package riscv_pkg;

  // Base opcodes (RV32I)
  localparam logic [6:0] OP_LUI    = 7'b0110111;
  localparam logic [6:0] OP_AUIPC  = 7'b0010111;
  localparam logic [6:0] OP_JAL    = 7'b1101111;
  localparam logic [6:0] OP_JALR   = 7'b1100111;
  localparam logic [6:0] OP_BRANCH = 7'b1100011;
  localparam logic [6:0] OP_LOAD   = 7'b0000011;
  localparam logic [6:0] OP_STORE  = 7'b0100011;
  localparam logic [6:0] OP_IMM    = 7'b0010011;
  localparam logic [6:0] OP_REG    = 7'b0110011;

  localparam logic [31:0] NOP = 32'h0000_0013;  // addi x0, x0, 0

  typedef enum logic [3:0] {
    ALU_ADD,
    ALU_SUB,
    ALU_SLL,
    ALU_SLT,
    ALU_SLTU,
    ALU_XOR,
    ALU_SRL,
    ALU_SRA,
    ALU_OR,
    ALU_AND,
    ALU_PASSB   // used by LUI
  } alu_op_t;

  // what gets written back to rd
  typedef enum logic [1:0] {
    WB_ALU,
    WB_MEM,
    WB_PC4      // JAL / JALR link address
  } wb_sel_t;

endpackage
