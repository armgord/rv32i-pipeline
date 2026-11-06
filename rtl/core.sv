// 5-stage RV32I pipeline: IF -> ID -> EX -> MEM -> WB
//
// - Branches and jumps are resolved in EX. When taken, IF/ID and ID/EX are
//   flushed (2-cycle penalty). No prediction yet: always predict not-taken.
// - EX/MEM -> EX and MEM/WB -> EX forwarding; WB -> ID handled in the regfile.
// - One-cycle stall on load-use.

module core
  import riscv_pkg::*;
#(
  parameter logic [31:0] RESET_PC = 32'h0000_0000
) (
  input  logic clk,
  input  logic rst
);

  // ---------------------------------------------------------------------------
  // Hazard / control signals between stages
  // ---------------------------------------------------------------------------
  logic        stall;        // load-use
  logic        flush;        // taken branch / jump in EX
  logic [31:0] ex_target;

  // ===========================================================================
  // IF
  // ===========================================================================
  logic [31:0] pc;
  logic [31:0] if_instr;

  always_ff @(posedge clk) begin
    if (rst)
      pc <= RESET_PC;
    else if (flush)
      pc <= ex_target;
    else if (!stall)
      pc <= pc + 32'd4;
  end

  imem u_imem (
    .addr  (pc),
    .instr (if_instr)
  );

  // IF/ID ----------------------------------------------------------------------
  logic        ifid_valid;
  logic [31:0] ifid_pc;
  logic [31:0] ifid_instr;

  always_ff @(posedge clk) begin
    if (rst || flush) begin
      ifid_valid <= 1'b0;
      ifid_pc    <= 32'b0;
      ifid_instr <= NOP;
    end else if (!stall) begin
      ifid_valid <= 1'b1;
      ifid_pc    <= pc;
      ifid_instr <= if_instr;
    end
  end

  // ===========================================================================
  // ID
  // ===========================================================================
  logic [4:0]  id_rs1, id_rs2, id_rd;
  logic [2:0]  id_funct3;
  logic [31:0] id_rs1_val, id_rs2_val, id_imm;

  logic        id_reg_write, id_mem_read, id_mem_write;
  logic        id_branch, id_jal, id_jalr, id_alu_a_pc, id_alu_b_imm;
  alu_op_t     id_alu_op;
  wb_sel_t     id_wb_sel;

  assign id_rs1    = ifid_instr[19:15];
  assign id_rs2    = ifid_instr[24:20];
  assign id_rd     = ifid_instr[11:7];
  assign id_funct3 = ifid_instr[14:12];

  // WB-stage signals (declared here, driven further down)
  logic        memwb_reg_write;
  logic [4:0]  memwb_rd;
  logic [31:0] memwb_wb_data;

  regfile u_rf (
    .clk    (clk),
    .we     (memwb_reg_write),
    .waddr  (memwb_rd),
    .wdata  (memwb_wb_data),
    .raddr1 (id_rs1),
    .raddr2 (id_rs2),
    .rdata1 (id_rs1_val),
    .rdata2 (id_rs2_val)
  );

  imm_gen u_imm (
    .instr (ifid_instr),
    .imm   (id_imm)
  );

  control u_ctrl (
    .instr     (ifid_instr),
    .reg_write (id_reg_write),
    .mem_read  (id_mem_read),
    .mem_write (id_mem_write),
    .branch    (id_branch),
    .jal       (id_jal),
    .jalr      (id_jalr),
    .alu_a_pc  (id_alu_a_pc),
    .alu_b_imm (id_alu_b_imm),
    .alu_op    (id_alu_op),
    .wb_sel    (id_wb_sel)
  );

  // ID/EX ----------------------------------------------------------------------
  logic        idex_valid;
  logic [31:0] idex_pc, idex_instr;
  logic [31:0] idex_rs1_val, idex_rs2_val, idex_imm;
  logic [4:0]  idex_rs1, idex_rs2, idex_rd;
  logic [2:0]  idex_funct3;
  logic        idex_reg_write, idex_mem_read, idex_mem_write;
  logic        idex_branch, idex_jal, idex_jalr, idex_alu_a_pc, idex_alu_b_imm;
  alu_op_t     idex_alu_op;
  wb_sel_t     idex_wb_sel;

  hazard_unit u_hazard (
    .idex_mem_read (idex_mem_read),
    .idex_rd       (idex_rd),
    .ifid_rs1      (id_rs1),
    .ifid_rs2      (id_rs2),
    .stall         (stall)
  );

  always_ff @(posedge clk) begin
    if (rst || flush || stall) begin
      // bubble: kill everything that has a side effect
      idex_valid     <= 1'b0;
      idex_reg_write <= 1'b0;
      idex_mem_read  <= 1'b0;
      idex_mem_write <= 1'b0;
      idex_branch    <= 1'b0;
      idex_jal       <= 1'b0;
      idex_jalr      <= 1'b0;
      idex_rd        <= 5'd0;
      idex_rs1       <= 5'd0;
      idex_rs2       <= 5'd0;
      idex_instr     <= NOP;
    end else begin
      idex_valid     <= ifid_valid;
      idex_pc        <= ifid_pc;
      idex_instr     <= ifid_instr;
      idex_rs1_val   <= id_rs1_val;
      idex_rs2_val   <= id_rs2_val;
      idex_imm       <= id_imm;
      idex_rs1       <= id_rs1;
      idex_rs2       <= id_rs2;
      idex_rd        <= id_rd;
      idex_funct3    <= id_funct3;
      idex_reg_write <= id_reg_write;
      idex_mem_read  <= id_mem_read;
      idex_mem_write <= id_mem_write;
      idex_branch    <= id_branch;
      idex_jal       <= id_jal;
      idex_jalr      <= id_jalr;
      idex_alu_a_pc  <= id_alu_a_pc;
      idex_alu_b_imm <= id_alu_b_imm;
      idex_alu_op    <= id_alu_op;
      idex_wb_sel    <= id_wb_sel;
    end
  end

  // ===========================================================================
  // EX
  // ===========================================================================
  logic [1:0]  fwd_a, fwd_b;
  logic [31:0] ex_rs1_val, ex_rs2_val;
  logic [31:0] alu_a, alu_b, alu_y;
  logic [31:0] ex_result;
  logic        branch_taken;

  // EX/MEM signals used for forwarding (declared here, driven below)
  logic        exmem_reg_write;
  logic [4:0]  exmem_rd;
  logic [31:0] exmem_result;

  forwarding_unit u_fwd (
    .idex_rs1        (idex_rs1),
    .idex_rs2        (idex_rs2),
    .exmem_reg_write (exmem_reg_write),
    .exmem_rd        (exmem_rd),
    .memwb_reg_write (memwb_reg_write),
    .memwb_rd        (memwb_rd),
    .fwd_a           (fwd_a),
    .fwd_b           (fwd_b)
  );

  always_comb begin
    case (fwd_a)
      2'b10:   ex_rs1_val = exmem_result;
      2'b01:   ex_rs1_val = memwb_wb_data;
      default: ex_rs1_val = idex_rs1_val;
    endcase
    case (fwd_b)
      2'b10:   ex_rs2_val = exmem_result;
      2'b01:   ex_rs2_val = memwb_wb_data;
      default: ex_rs2_val = idex_rs2_val;
    endcase
  end

  assign alu_a = idex_alu_a_pc  ? idex_pc  : ex_rs1_val;
  assign alu_b = idex_alu_b_imm ? idex_imm : ex_rs2_val;

  alu u_alu (
    .a  (alu_a),
    .b  (alu_b),
    .op (idex_alu_op),
    .y  (alu_y)
  );

  // branch compare
  always_comb begin
    case (idex_funct3)
      3'b000:  branch_taken = (ex_rs1_val == ex_rs2_val);                  // BEQ
      3'b001:  branch_taken = (ex_rs1_val != ex_rs2_val);                  // BNE
      3'b100:  branch_taken = ($signed(ex_rs1_val) <  $signed(ex_rs2_val)); // BLT
      3'b101:  branch_taken = ($signed(ex_rs1_val) >= $signed(ex_rs2_val)); // BGE
      3'b110:  branch_taken = (ex_rs1_val <  ex_rs2_val);                  // BLTU
      3'b111:  branch_taken = (ex_rs1_val >= ex_rs2_val);                  // BGEU
      default: branch_taken = 1'b0;
    endcase
  end

  assign flush     = (idex_branch && branch_taken) || idex_jal || idex_jalr;
  assign ex_target = idex_jalr ? {alu_y[31:1], 1'b0} : (idex_pc + idex_imm);

  // JAL/JALR write the return address instead of the ALU output
  assign ex_result = (idex_wb_sel == WB_PC4) ? (idex_pc + 32'd4) : alu_y;

  // EX/MEM ---------------------------------------------------------------------
  logic        exmem_valid;
  logic [31:0] exmem_pc, exmem_instr;
  logic [31:0] exmem_store_data;
  logic [2:0]  exmem_funct3;
  logic        exmem_mem_read, exmem_mem_write;
  wb_sel_t     exmem_wb_sel;

  always_ff @(posedge clk) begin
    if (rst) begin
      exmem_valid     <= 1'b0;
      exmem_reg_write <= 1'b0;
      exmem_mem_read  <= 1'b0;
      exmem_mem_write <= 1'b0;
      exmem_rd        <= 5'd0;
    end else begin
      exmem_valid      <= idex_valid;
      exmem_pc         <= idex_pc;
      exmem_instr      <= idex_instr;
      exmem_result     <= ex_result;
      exmem_store_data <= ex_rs2_val;
      exmem_rd         <= idex_rd;
      exmem_funct3     <= idex_funct3;
      exmem_reg_write  <= idex_reg_write;
      exmem_mem_read   <= idex_mem_read;
      exmem_mem_write  <= idex_mem_write;
      exmem_wb_sel     <= idex_wb_sel;
    end
  end

  // ===========================================================================
  // MEM
  // ===========================================================================
  logic [31:0] mem_rdata;
  logic [31:0] mem_wb_data;

  dmem u_dmem (
    .clk   (clk),
    .we    (exmem_mem_write),
    .addr  (exmem_result),
    .wdata (exmem_store_data),
    .rdata (mem_rdata)
  );

  // TODO: use exmem_funct3 for byte/halfword loads
  assign mem_wb_data = (exmem_wb_sel == WB_MEM) ? mem_rdata : exmem_result;

  // MEM/WB ---------------------------------------------------------------------
  logic        memwb_valid;
  logic [31:0] memwb_pc, memwb_instr;

  always_ff @(posedge clk) begin
    if (rst) begin
      memwb_valid     <= 1'b0;
      memwb_reg_write <= 1'b0;
      memwb_rd        <= 5'd0;
    end else begin
      memwb_valid     <= exmem_valid;
      memwb_pc        <= exmem_pc;
      memwb_instr     <= exmem_instr;
      memwb_wb_data   <= mem_wb_data;
      memwb_rd        <= exmem_rd;
      memwb_reg_write <= exmem_reg_write;
    end
  end

  // ===========================================================================
  // WB -- the write itself happens inside u_rf
  // ===========================================================================

endmodule
