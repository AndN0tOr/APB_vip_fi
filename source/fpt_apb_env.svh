`ifndef FPT_APB_ENV_SVH
`define FPT_APB_ENV_SVH

// import uvm_pkg::*;
// `include "uvm_macros.svh" 

`include "../tests/fpt_apb_sys_config.svh"
`include "../tests/fpt_apb_mem_model_t.svh"

class fpt_apb_env extends uvm_env;
	`uvm_component_utils(fpt_apb_env)
	
	//--------------------------------------------------------------------
	//	Component Members
	//--------------------------------------------------------------------	
	fpt_apb_mem_model_t fpt_mem_model;
	fpt_apb_sys_config fpt_sys_config;
	fpt_apb_master_agent fpt_master_agents[];
	fpt_apb_slave_agent fpt_slave_agents[];
	fpt_apb_vif_t vif;

	//--------------------------------------------------------------------
	//	Methods
	//--------------------------------------------------------------------
	extern function new(string name = "fpt_apb_env", uvm_component parent= null );
	extern virtual function void build_phase(uvm_phase phase);	
endclass

// Function: new
// Definition: class constructor
function fpt_apb_env::new(string name = "fpt_apb_env", uvm_component parent = null);
	super.new(name, parent);
endfunction

// Function: build_phase
// Definition: standard uvm_phase
function void fpt_apb_env::build_phase(uvm_phase phase);
	super.build_phase(phase);
	if (!uvm_config_db#(fpt_apb_sys_config)::get(this, "", "fpt_apb_sys_config", fpt_sys_config)) begin
        `uvm_fatal(get_full_name(), "Cannot get fpt_apb_sys_config from config_db!")
    end
	
	fpt_master_agents = new[fpt_sys_config.fpt_master_numb];
	fpt_slave_agents  = new[fpt_sys_config.fpt_slave_numb];
	foreach (fpt_master_agents[i]) begin
		fpt_master_agents[i] = fpt_apb_master_agent::type_id::create($sformatf("fpt_apb_master_agent_%0d", i), this);
	end
	foreach (fpt_slave_agents[i]) begin
		fpt_slave_agents[i] = fpt_apb_slave_agent::type_id::create($sformatf("fpt_apb_slave_agent_%0d", i), this);
	end
	if (!uvm_config_db#(fpt_apb_vif_t)::get(this, "", "fpt_apb_vif", vif)) begin
		`uvm_fatal(get_full_name(), "No virtual interface specified for env")
	end
		
endfunction: build_phase
`endif
