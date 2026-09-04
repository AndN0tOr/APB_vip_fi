## QuestaSim Simulation Commands

# Variables
VLIB = vlib
VMAP = vmap
VLOG = vlog
VSIM = vsim

LIB_NAME = work
INCDIRS = +incdir+common +incdir+master +incdir+slave +incdir+tests

SRC_COMMON = $(wildcard common/*.sv) $(wildcard common/*.v)
SRC_MASTER = $(wildcard master/*.sv) $(wildcard master/*.v)
SRC_SLAVE  = $(wildcard slave/*.sv)  $(wildcard slave/*.v)
SRC_TESTS  = $(wildcard tests/*.sv)  $(wildcard tests/*.v)

ALL_SRCS = $(SRC_COMMON) $(SRC_MASTER) $(SRC_SLAVE) $(SRC_TESTS)
TOP_TEST = top_tb

all: lib comp sim

lib:
	@if [ ! -d $(LIB_NAME) ]; then \
		$(VLIB) $(LIB_NAME); \
		$(VMAP) work $(LIB_NAME); \
	fi

# Compile ALL files
comp: lib
	$(VLOG) -work $(LIB_NAME) $(INCDIRS) $(ALL_SRCS)

# NEW: Compile a SINGLE specific file
# Usage: make file FILE=master/master_driver.sv
file: lib
	@if [ -z "$(FILE)" ]; then \
		echo "Error: Please specify a file. Example: make file FILE=master/driver.sv"; \
		exit 1; \
	fi
	$(VLOG) -work $(LIB_NAME) $(INCDIRS) $(FILE)

sim:
	$(VSIM) -c -do "run -all; quit" $(LIB_NAME).$(TOP_TEST)

sim_gui:
	$(VSIM) -gui $(LIB_NAME).$(TOP_TEST)

clean:
	rm -rf $(LIB_NAME) transcript *.wlf vsim.wlf

.PHONY: all lib comp file sim sim_gui clean
