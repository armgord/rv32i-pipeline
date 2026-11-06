# Icarus Verilog flow. Needs iverilog >= 11 (-g2012 for SystemVerilog).

RTL = rtl/riscv_pkg.sv \
      rtl/alu.sv \
      rtl/regfile.sv \
      rtl/imm_gen.sv \
      rtl/control.sv \
      rtl/hazard_unit.sv \
      rtl/forwarding_unit.sv \
      rtl/imem.sv \
      rtl/dmem.sv \
      rtl/core.sv

TB    = tb/tb_core.sv
TESTS = alu forward load_use branch

.PHONY: all test clean

all: test

build/sim: $(RTL) $(TB)
	@mkdir -p build
	iverilog -g2012 -o $@ $(RTL) $(TB)

# run every test and print PASS/FAIL
test: build/sim
	@for t in $(TESTS); do \
		vvp -n build/sim +HEX=tests/$$t.hex +EXP=tests/$$t.exp | grep -E "PASS|FAIL|expected"; \
	done

# make run-branch  -> instruction trace for one test
run-%: build/sim
	vvp -n build/sim +HEX=tests/$*.hex +EXP=tests/$*.exp +TRACE +CYCLES=60

# make wave-branch -> build/wave.vcd (open with gtkwave)
wave-%: build/sim
	vvp -n build/sim +HEX=tests/$*.hex +EXP=tests/$*.exp +VCD +CYCLES=100

clean:
	rm -rf build
