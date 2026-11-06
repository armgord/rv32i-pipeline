// Testbench for the core.
//
//   +HEX=<file>    program to load into instruction memory (required)
//   +EXP=<file>    expected register values, one "xN <hex>" per line
//   +CYCLES=<n>    how long to run (default 500)
//   +TRACE         print every instruction that reaches WB
//   +VCD           dump build/wave.vcd
//
// Test programs end in "jal x0, 0" (jump to self), so after enough cycles the
// register file is stable and can be checked.

`timescale 1ns/1ps

module tb_core;

  logic clk = 1'b0;
  logic rst = 1'b1;

  always #5 clk = ~clk;

  core dut (
    .clk (clk),
    .rst (rst)
  );

  reg [8*256-1:0] hexfile;
  reg [8*256-1:0] expfile;
  int max_cycles = 500;
  int cycle      = 0;
  int retired    = 0;
  int errors     = 0;
  int checked    = 0;

  // ---------------------------------------------------------------------------
  initial begin
    if (!$value$plusargs("HEX=%s", hexfile)) begin
      $display("usage: vvp sim +HEX=<file> [+EXP=<file>] [+CYCLES=n] [+TRACE] [+VCD]");
      $finish;
    end
    if (!$value$plusargs("EXP=%s", expfile)) expfile = "";
    if (!$value$plusargs("CYCLES=%d", max_cycles)) max_cycles = 500;

    for (int i = 0; i < 1024; i++) dut.u_imem.mem[i] = 32'h0000_0013;
    $readmemh(hexfile, dut.u_imem.mem);

    if ($test$plusargs("VCD")) begin
      $dumpfile("build/wave.vcd");
      $dumpvars(0, tb_core);
    end

    repeat (2) @(posedge clk);
    rst <= 1'b0;

    repeat (max_cycles) @(posedge clk);
    #1;
    check_regs();
    $finish;
  end

  // ---------------------------------------------------------------------------
  // cycle count + optional trace
  always @(posedge clk) begin
    if (!rst) begin
      cycle <= cycle + 1;
      if (dut.memwb_valid) begin
        retired <= retired + 1;
        if ($test$plusargs("TRACE")) begin
          if (dut.memwb_reg_write && dut.memwb_rd != 0)
            $display("[%4d] pc=%08h  %08h  x%0d <= %08h",
                     cycle, dut.memwb_pc, dut.memwb_instr, dut.memwb_rd, dut.memwb_wb_data);
          else
            $display("[%4d] pc=%08h  %08h", cycle, dut.memwb_pc, dut.memwb_instr);
        end
      end
    end
  end

  // ---------------------------------------------------------------------------
  task automatic dump_regs();
    for (int i = 0; i < 32; i += 4)
      $display("x%-2d %08h   x%-2d %08h   x%-2d %08h   x%-2d %08h",
               i,   dut.u_rf.regs[i],   i+1, dut.u_rf.regs[i+1],
               i+2, dut.u_rf.regs[i+2], i+3, dut.u_rf.regs[i+3]);
  endtask

  task automatic check_regs();
    integer fd;
    integer n;
    integer idx;
    reg [31:0]      expv;
    reg [8*128-1:0] line;

    $display("cycles=%0d retired=%0d", cycle, retired);

    if (expfile == "") begin
      dump_regs();
      $finish;
    end

    fd = $fopen(expfile, "r");
    if (fd == 0) begin
      $display("could not open %0s", expfile);
      $finish;
    end

    while ($fgets(line, fd)) begin
      n = $sscanf(line, "x%d %h", idx, expv);
      if (n == 2) begin
        checked++;
        if (dut.u_rf.regs[idx] !== expv) begin
          $display("  x%0d = %08h, expected %08h", idx, dut.u_rf.regs[idx], expv);
          errors++;
        end
      end
    end
    $fclose(fd);

    if (errors == 0) $display("PASS  %0s (%0d regs checked)", hexfile, checked);
    else begin
      $display("FAIL  %0s (%0d/%0d wrong)", hexfile, errors, checked);
      dump_regs();
    end
  endtask

endmodule
