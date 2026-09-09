`ifndef FPT_APB_SLAVE_SEQUENCER_SVH
`define FPT_APB_SLAVE_SEQUENCER_SVH

class fpt_apb_slave_sequencer extends uvm_sequencer#(fpt_apb_slave_seq_item);

	`uvm_component_utils(fpt_apb_slave_sequencer)
	
	extern function new (string name = "fpt_apb_slave_sequencer",  uvm_component parent = null);
endclass
	
// Function: new
function fpt_apb_slave_sequencer::new(string name = "fpt_apb_slave_sequencer", uvm_component parent = null);
    super.new(name, parent);
endfunction

`endif