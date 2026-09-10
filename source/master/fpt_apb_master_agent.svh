`ifndef FPT_APB_MASTER_AGENT_SVH
`define FPT_APB_MASTER_AGENT_SVH

class fpt_apb_master_agent extends uvm_agent;
    `uvm_component_utils(fpt_apb_master_agent)

    // Need config
    fpt_apb_master_seq_item m_apb_master_seq_item;
    fpt_apb_master_driver m_apb_master_driver;
    fpt_apb_master_sequencer m_apb_master_sequencer;
    //Need monitor

    extern function new(string name = "fpt_apb_master_agent", uvm_component parent = null);
	extern virtual function void build_phase(uvm_phase phase);
	extern virtual function void connect_phase(uvm_phase phase);
	
endclass

// Function: new
function fpt_apb_master_agent::new(string name = "fpt_apb_master_agent", uvm_component parent = null);
    super.new(name, parent);
endfunction

// Function: build_phase
function void fpt_apb_master_agent::build_phase(uvm_phase phase);
	super.build_phase(phase);
	
    // Need config on later versions

    m_apb_master_seq_item    = fpt_apb_master_seq_item::type_id::create("m_apb_master_seq_item");
    m_apb_master_driver      = fpt_apb_master_driver::type_id::create("m_apb_master_driver", this);
    m_apb_master_sequencer   = fpt_apb_master_sequencer::type_id::create("m_apb_master_sequencer", this);
endfunction: build_phase	

function void fpt_apb_master_agent::connect_phase(uvm_phase phase);
	super.connect_phase(phase);
	
	// if(m_cfg.is_active == UVM_ACTIVE) begin
	m_apb_master_driver.seq_item_port.connect(m_apb_master_sequencer.seq_item_export);
	// end	
	
endfunction	
`endif