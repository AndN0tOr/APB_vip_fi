`ifndef FPT_APB_SLAVE_DRIVER_SVH
`define FPT_APB_SLAVE_DRIVER_SVH

class fpt_apb_slave_driver extends uvm_driver#(fpt_apb_slave_seq_item);
    `uvm_component_utils(fpt_apb_slave_driver)

    virtual fpt_apb_if vif;
    fpt_apb_slave_seq_item apb_slave_seq_item;

    extern function new(string name = "fpt_apb_slave_driver", uvm_component parent = null);
	extern virtual function void build_phase(uvm_phase phase);
	extern virtual task run_phase(uvm_phase phase);
	extern virtual task wait_for_reset();
	extern virtual task get_and_drive();
	extern virtual task init_signals();
endclass

// Function: new
function new(string name = "fpt_apb_slave_driver", uvm_component parent = null);
    super.new(name, parent);
endfunction

// Function: build_phase
function void fpt_apb_slave_driver::build_phase(uvm_phase phase);
	super.build_phase(phase);
	if (!uvm_config_db#(virtual fpt_apb_vif)::get(this, "", "fpt_apb_vif", vif)) begin
		`uvm_fatal(get_full_name(), "No virtual interface specified for fpt_apb_slave_driver")
	end 
endfunction: build_phase	

// Task: run_phase
task fpt_apb_slave_driver::run_phase(uvm_phase phase);
	super.run_phase(phase);

endtask

