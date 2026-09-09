`ifndef FPT_APB_SLAVE_AGENT_SVH
`define FPT_APB_SLAVE_AGENT_SVH

class fpt_apb_slave_agent extends uvm_agent;
    `uvm_component_utils(fpt_apb_slave_agent)

    // Need config
    fpt_apb_slave_seq_item m_apb_slave_seq_item;
    fpt_apb_slave_driver m_apb_slave_driver;
    fpt_apb_slave_sequence m_apb_slave_sequence;
    fpt_apb_slave_sequencer m_apb_slave_sequencer;
    //Need monitor

    extern function new(string name = "fpt_apb_slave_agent", uvm_component parent = null);
	extern virtual function void build_phase(uvm_phase phase);
	extern virtual function void connect_phase(uvm_phase phase);
	
endclass

// Function: new
function new(string name = "fpt_apb_slave_agent", uvm_component parent = null);
    super.new(name, parent);
endfunction

// Function: build_phase
function void fpt_apb_slave_agent::build_phase(uvm_phase phase);
	super.build_phase(phase);
	
    // Need config on later versions

    m_apb_slave_seq_item    = fpt_apb_slave_seq_item::type_id::create("m_apb_slave_seq_item");
    m_apb_slave_seq	        = fpt_apb_slave_seq::type_id::create("m_apb_slave_seq");

endfunction: build_phase	

function void apb_slave_agent::connect_phase(uvm_phase phase);
	super.connect_phase(phase);
	
	// if(m_cfg.is_active == UVM_ACTIVE) begin
	m_apb_slave_driver.seq_item_port.connect(m_apb_slave_sequencer.seq_item_export);
	// end	
	
endfunction	
endtask
`endif