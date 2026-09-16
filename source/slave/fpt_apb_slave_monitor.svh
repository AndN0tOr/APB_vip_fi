`ifndef FPT_APB_SLAVE_MONITOR_SVH
`define FPT_APB_SLAVE_MONITOR_SVH

class fpt_apb_slave_monitor extends uvm_monitor;
    `uvm_component_utils(fpt_apb_slave_monitor)
    fpt_apb_vif_t vif;

    extern function new (string name = "fpt_apb_slave_monitor", uvm_component parent = null);
    extern virtual function void build_phase(uvm_phase phase);
    extern virtual task run_phase(uvm_phase phase);
endclass

function fpt_apb_slave_monitor::new(string name = "fpt_apb_slave_monitor", uvm_component parent = null);
    super.new(name, parent);
endfunction

function void fpt_apb_slave_monitor::build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(fpt_apb_vif_t)::get(this, "", "fpt_apb_vif", vif)) begin
        `uvm_fatal(get_full_name(), "No virtual interface specified for fpt_apb_slave_monitor")
    end
endfunction: build_phase

task fpt_apb_slave_monitor::run_phase(uvm_phase phase);
    super.run_phase(phase);
    forever begin
        @(posedge vif.PCLK);
        if (!vif.PRESETn) begin
            `uvm_info(get_type_name(), "RESET Asserted.", UVM_HIGH)
            @(posedge vif.PRESETn);
            `uvm_info(get_type_name(), "RESET Released.", UVM_HIGH)
        end
    end
endtask: run_phase

`endif // FPT_APB_SLAVE_MONITOR_SVH