`ifndef FPT_APB_MASTER_SEQUENCER_SVH
`define FPT_APB_MASTER_SEQUENCER_SVH

class fpt_apb_master_sequencer extends uvm_sequencer#(fpt_apb_master_seq_item);

	`uvm_component_utils(fpt_apb_master_sequencer)
	
	extern function new (string name = "fpt_apb_master_sequencer",  uvm_component parent = null);
endclass
	
// Function: new
function fpt_apb_master_sequencer::new(string name = "fpt_apb_master_sequencer", uvm_component parent = null);
    super.new(name, parent);
endfunction

`endif