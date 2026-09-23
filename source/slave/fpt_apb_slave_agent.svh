`ifndef FPT_APB_SLAVE_AGENT_SVH
`define FPT_APB_SLAVE_AGENT_SVH

class fpt_apb_slave_agent extends uvm_agent;
    `uvm_component_utils(fpt_apb_slave_agent)

    // Need config
    fpt_apb_slave_seq_item m_apb_slave_seq_item;
    fpt_apb_slave_driver m_apb_slave_driver;
    fpt_apb_slave_sequencer m_apb_slave_sequencer;
    fpt_apb_slave_monitor m_apb_slave_monitor;
    fpt_common_mem_model_t fpt_mem_model;
    fpt_apb_sys_config fpt_sys_config;
    uvm_analysis_port #(fpt_apb_slave_seq_item) item_collected_port;

    extern function new(string name = "fpt_apb_slave_agent", uvm_component parent = null);
	extern virtual function void build_phase(uvm_phase phase);
	extern virtual function void connect_phase(uvm_phase phase);
	
endclass

// Function: new
function fpt_apb_slave_agent::new(string name = "fpt_apb_slave_agent", uvm_component parent = null);
    super.new(name, parent);
    item_collected_port = new("item_collected_port", this);
endfunction

// Function: build_phase
function void fpt_apb_slave_agent::build_phase(uvm_phase phase);
	super.build_phase(phase);
	
    // Need config on later versions

    m_apb_slave_seq_item    = fpt_apb_slave_seq_item::type_id::create("m_apb_slave_seq_item");
    m_apb_slave_driver      = fpt_apb_slave_driver::type_id::create("m_apb_slave_driver", this);
    m_apb_slave_sequencer   = fpt_apb_slave_sequencer::type_id::create("m_apb_slave_sequencer", this);
    m_apb_slave_monitor     = fpt_apb_slave_monitor::type_id::create("m_apb_slave_monitor", this);
    uvm_config_db#(fpt_apb_sys_config)::get(this, "", "fpt_sys_config", fpt_sys_config);
endfunction: build_phase	

function void fpt_apb_slave_agent::connect_phase(uvm_phase phase);
	super.connect_phase(phase);
	
	// if(m_cfg.is_active == UVM_ACTIVE) begin
    m_apb_slave_driver.fpt_mem_model = this.fpt_mem_model;
	m_apb_slave_driver.seq_item_port.connect(m_apb_slave_sequencer.seq_item_export);
	m_apb_slave_monitor.item_collected_port.connect(item_collected_port);
	// end	
	
endfunction	
`endif
