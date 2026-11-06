# RV32I 5-Stage Pipelined Core (SystemVerilog)

A classic 5-stage in-order RISC-V core (IF / ID / EX / MEM / WB) written in SystemVerilog, simulated with Icarus Verilog.
**Status: work in progress.** Most of RV32I runs and the directed tests pass, but it isn't complete or compliance-tested yet (see the TODO list below).

## Pipeline

```
        +----+    +----+    +----+    +-----+    +----+
  PC -> | IF | -> | ID | -> | EX | -> | MEM | -> | WB |
        +----+    +----+    +----+    +-----+    +----+
           ^         |  ^     |  ^       |          |
           |   stall |  |     |  +-- fwd-+----------+
           +---------+--+-----+  (EX/MEM, MEM/WB -> EX)
              redirect on taken branch / jump (flush IF/ID, ID/EX)
```

- **Branches/jumps** are resolved in EX. The core always predicts not-taken; on a taken branch, JAL, or JALR it flushes IF/ID and ID/EX (2-cycle penalty).
- **Forwarding**: EX/MEM → EX and MEM/WB → EX, for both ALU operands and store data. EX/MEM has priority because it holds the newer value.
- **WB → ID**: the register file passes the write data through when WB writes the same register ID is reading in that cycle, so no extra forwarding path is needed.
- **Load-use hazard**: 1-cycle stall (PC and IF/ID held, bubble inserted into ID/EX), after which the value is forwarded from MEM/WB.
- Memories are simple arrays: combinational-read instruction memory, and data memory with synchronous write and combinational read.

## Files

```
rtl/
  riscv_pkg.sv        opcodes, ALU op / writeback enums
  core.sv             top level: pipeline registers + stage logic
  control.sv          main decoder
  imm_gen.sv          I/S/B/U/J immediates
  alu.sv
  regfile.sv          32x32, 2R/1W, write-through
  forwarding_unit.sv
  hazard_unit.sv      load-use detection
  imem.sv, dmem.sv
tb/
  tb_core.sv          loads a .hex program, runs N cycles, checks registers
tests/
  *.hex               hand-assembled test programs (assembly in comments)
  *.exp               expected register values
```

## Running

Requires Icarus Verilog 11 or newer.

```
make test            # run all tests
make run-branch      # instruction trace for one test
make wave-load_use   # dump build/wave.vcd for GTKWave
```

Current output:

```
PASS  tests/alu.hex (23 regs checked)
PASS  tests/forward.hex (11 regs checked)
PASS  tests/load_use.hex (12 regs checked)
PASS  tests/branch.hex (10 regs checked)
```

Each test program ends with `jal x0, 0` (a jump to itself), so the register file stops changing and can be checked after a fixed number of cycles.

| Test       | What it covers |
|------------|----------------|
| `alu`      | all R-type and I-type ALU ops, LUI, AUIPC |
| `forward`  | back-to-back dependencies, writes to x0, same rd written twice in a row, WB→ID |
| `load_use` | load-use stall, store data forwarding, load→store dependency, negative offsets |
| `branch`   | all six branch types (signed and unsigned), loop, JAL/JALR call and return |

## TODO

- [ ] Byte/halfword loads and stores (LB, LH, LBU, LHU, SB, SH). funct3 already reaches MEM; dmem needs byte enables.
- [ ] FENCE, ECALL/EBREAK (they currently decode as NOPs)
- [ ] Hazard unit compares rs2 even for instructions that don't use it, which causes some unnecessary stalls
- [ ] Build tests with the riscv-gnu-toolchain instead of hand-assembling them
- [ ] Run the official riscv-tests (rv32ui)
- [ ] Performance counters (cycles / instructions retired → CPI)
- [ ] Simple branch predictor (BTFN or 2-bit BHT) and comparison of CPI with and without it
- [ ] Synthesize for an Intel MAX 10 FPGA and check Fmax / resource usage
